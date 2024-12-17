const std = @import("std");
const builtin = @import("builtin");

const flags = @import("flags");
const gcat = @import("gatorcat");

pub const std_options: std.Options = .{
    .log_level = .warn,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var args = try std.process.argsWithAllocator(gpa.allocator());
    defer args.deinit();

    const parsed_args = flags.parse(&args, "gatorcat", Flags, .{}) catch |err| switch (err) {
        error.PrintedHelp => std.process.exit(0),
        else => |scoped_err| return scoped_err,
    };

    switch (parsed_args.command) {
        .scan => |scan_args| {
            var raw_socket = switch (builtin.target.os.tag) {
                .linux => try gcat.nic.RawSocket.init(scan_args.ifname),
                .windows => try gcat.nic.WindowsRawSocket.init(scan_args.ifname),
                else => @compileError("unsupported target os"),
            };
            defer raw_socket.deinit();

            var port = gcat.Port.init(raw_socket.linkLayer(), .{});
            try port.ping(scan_args.recv_timeout_us);

            try scan(
                &port,
                scan_args.recv_timeout_us,
                scan_args.eeprom_timeout_us,
                scan_args.INIT_timeout_us,
                scan_args.PREOP_timeout_us,
                scan_args.mbx_timeout_us,
                scan_args.ring_position,
            );
        },

        .benchmark => |benchmark_args| {
            var raw_socket = switch (builtin.target.os.tag) {
                .linux => try gcat.nic.RawSocket.init(benchmark_args.ifname),
                .windows => try gcat.nic.WindowsRawSocket.init(benchmark_args.ifname),
                else => @compileError("unsupported target os"),
            };
            defer raw_socket.deinit();

            var port = gcat.Port.init(raw_socket.linkLayer(), .{});
            try port.ping(benchmark_args.recv_timeout_us);
            try benchmark(
                &port,
                benchmark_args.recv_timeout_us,
                benchmark_args.duration_s,
                benchmark_args.cycle_time_us,
                benchmark_args.rt_prio,
                benchmark_args.affinity,
            );
        },
    }
}

// CLI options
const Flags = struct {
    // Optional description of the program.
    pub const description =
        \\The GatorCAT CLI.
    ;
    // sub commands
    command: union(enum) {
        // scan bus
        scan: struct {
            ifname: [:0]const u8,
            ring_position: ?u16 = null,
            recv_timeout_us: u32 = 10_000,
            eeprom_timeout_us: u32 = 10_000,
            INIT_timeout_us: u32 = 5_000_000,
            PREOP_timeout_us: u32 = 10_000_000,
            mbx_timeout_us: u32 = 50_000,
            pub const descriptions = .{
                .ifname = "Network interface to use for the bus scan.",
                .recv_timeout_us = "Frame receive timeout in microseconds.",
                .eeprom_timeout_us = "SII EEPROM timeout in microseconds.",
                .INIT_timeout_us = "state transition to INIT timeout in microseconds.",
                .ring_position = "Optionally specify only a single subdevice at this ring position to be scanned.",
            };
        },

        benchmark: struct {
            ifname: [:0]const u8,
            recv_timeout_us: u32 = 10_000,
            duration_s: f64 = 10.0,
            cycle_time_us: u32 = 2000,
            rt_prio: ?i32 = null,
            affinity: ?u10 = null,

            pub const descriptions = .{
                .ifname = "Network interface to use for the benchmark (e.g. \"eth0\").",
                .recv_timeout_us = "Frame receive timeout in microseconds.",
                .duration_s = "Duration of the test in seconds.",
                .cycle_time_us = "Intended cycle time in microseconds.",
                .rt_prio = "Set the real-time priority of this process.",
                .affinity = "Set the cpu affinity of the this process.",
            };
        },

        pub const descriptions = .{
            .scan = "Scan the EtherCAT bus and print information about the subdevices.",
            .benchmark = "Benchmark the performance of the EtherCAT bus.",
        };
    },
};

fn benchmark(
    port: *gcat.Port,
    recv_timeout_us: u32,
    duration_s: f64,
    cycle_time_us: u32,
    maybe_rt_prio: ?i32,
    maybe_affinity: ?u10,
) !void {
    var writer = std.io.getStdOut().writer();
    if (builtin.os.tag == .linux) {
        if (maybe_affinity) |affinity| {
            // using pid = 0 means this process will have the scheduler set.
            const cpu_set: std.os.linux.cpu_set_t = @bitCast(@as(u1024, 1) << affinity);
            try std.os.linux.sched_setaffinity(0, &cpu_set);
            try writer.print("Set cpu affinity to {}.\n", .{affinity});
        }
        if (maybe_rt_prio) |rt_prio| {
            // using pid = 0 means this process will have the scheduler set.
            const rval = std.os.linux.sched_setscheduler(0, .{ .mode = .FIFO }, &.{
                .priority = rt_prio,
            });
            switch (std.posix.errno(rval)) {
                .SUCCESS => {
                    try writer.print("Set real-time priority to {}.\n", .{rt_prio});
                },
                else => |err| {
                    try writer.print("Error when setting real-time priority: {}\n", .{err});
                    return error.CannotSetRealtimePriority;
                },
            }
        }
    }

    try writer.print("benchmarking for {d:.2}s...\n", .{duration_s});

    var run_timer = try std.time.Timer.start();
    var n_cycles: u64 = 0;
    var max_cycle_time_ns: u64 = 0;
    var min_cycle_time_ns: u64 = @as(u64, recv_timeout_us) * std.time.ns_per_us;
    var cycle_timer = try std.time.Timer.start();
    const first_cycle_time = std.time.Instant.now() catch @panic("Timer unsupported");
    while (@as(f64, @floatFromInt(run_timer.read())) < duration_s * std.time.ns_per_s) {
        try port.ping(recv_timeout_us);
        n_cycles += 1;

        gcat.sleepUntilNextCycle(first_cycle_time, cycle_time_us);
        const cycle_time_ns = cycle_timer.read();
        cycle_timer.reset();
        if (cycle_time_ns > max_cycle_time_ns) {
            max_cycle_time_ns = cycle_time_ns;
        }
        if (cycle_time_ns < min_cycle_time_ns) {
            min_cycle_time_ns = cycle_time_ns;
        }
    }
    const total_time_s: f64 = @as(f64, @floatFromInt(run_timer.read())) / std.time.ns_per_s;
    const cycles_per_second: f64 = @as(f64, @floatFromInt(n_cycles)) / total_time_s;
    const max_cycle_time_s: f64 = @as(f64, @floatFromInt(max_cycle_time_ns)) / std.time.ns_per_s;
    const min_cycle_time_s: f64 = @as(f64, @floatFromInt(min_cycle_time_ns)) / std.time.ns_per_s;
    try writer.print("Completed {} cycles in {d:.2}s or {d:.2} cycles/s.\n", .{ n_cycles, total_time_s, cycles_per_second });
    try writer.print("Max cycle time: {d:.6}s.\n", .{max_cycle_time_s});
    try writer.print("Min cycle time: {d:.6}s.\n", .{min_cycle_time_s});
}

fn scan(
    port: *gcat.Port,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
    INIT_timeout_us: u32,
    PREOP_timeout_us: u32,
    mbx_timeout_us: u32,
    ring_position: ?u16,
) !void {
    var scanner = gcat.Scanner.init(port, .{ .eeprom_timeout_us = eeprom_timeout_us, .recv_timeout_us = recv_timeout_us });
    var writer = std.io.getStdOut().writer();

    const num_subdevices = try scanner.countSubdevices();
    try writer.print("Detected {} subdevices.\n", .{num_subdevices});

    try scanner.busInit(INIT_timeout_us, num_subdevices);
    try writer.print("Successfully reached INIT.\n", .{});

    try scanner.assignStationAddresses(num_subdevices);
    try writer.print("Successfully assigned station addresses.\n", .{});
    try writer.print("\n", .{});

    // summary table
    try printBusSummary(writer, port, recv_timeout_us, eeprom_timeout_us, num_subdevices);
    // detailed info on each subdevice
    if (ring_position) |position| {
        try printSubdeviceDetails(writer, port, recv_timeout_us, eeprom_timeout_us, @intCast(position));
        try printSubdeviceSIIPDOs(
            writer,
            port,
            recv_timeout_us,
            eeprom_timeout_us,
            gcat.SubDevice.stationAddressFromRingPos(@intCast(position)),
        );
        var subdevice = try scanner.subdevicePREOP(PREOP_timeout_us, position);
        try printSubdeviceCoePDOs(writer, port, recv_timeout_us, mbx_timeout_us, &subdevice);
    } else {
        for (0..num_subdevices) |i| {
            try printSubdeviceDetails(writer, port, recv_timeout_us, eeprom_timeout_us, @intCast(i));
            try printSubdeviceSIIPDOs(
                writer,
                port,
                recv_timeout_us,
                eeprom_timeout_us,
                gcat.SubDevice.stationAddressFromRingPos(@intCast(i)),
            );
            var subdevice = try scanner.subdevicePREOP(PREOP_timeout_us, @intCast(i));
            try printSubdeviceCoePDOs(writer, port, recv_timeout_us, mbx_timeout_us, &subdevice);
        }
    }
}

fn printBusSummary(
    writer: anytype,
    port: *gcat.Port,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
    num_subdevices: u16,
) !void {
    try writer.print("", .{});
    try writer.print("Ring                      Auto-incr.  Station                 Product    Revision\n", .{});
    try writer.print("Pos.    Order ID             Address  Address   Vendor ID        Code      Number\n", .{});
    try writer.print("---------------------------------------------------------------------------------\n", .{});
    for (0..num_subdevices) |i| {
        const ring_position: u16 = @intCast(i);
        const autoinc_address: u16 = gcat.SubDevice.autoincAddressFromRingPos(ring_position);
        const station_address: u16 = gcat.SubDevice.stationAddressFromRingPos(ring_position);

        const info = try gcat.sii.readSubdeviceInfoCompact(
            port,
            station_address,
            recv_timeout_us,
            eeprom_timeout_us,
        );

        const cat_general = try gcat.sii.readGeneralCatagory(
            port,
            station_address,
            recv_timeout_us,
            eeprom_timeout_us,
        );

        var order_id: []const u8 = "";
        if (cat_general) |general| {
            const maybe_order_id_string = try gcat.sii.readSIIString(
                port,
                station_address,
                general.order_idx,
                recv_timeout_us,
                eeprom_timeout_us,
            );
            if (maybe_order_id_string) |order_id_string| {
                order_id = order_id_string.slice();
            }
        }
        try writer.print(
            "{d:<5}   {s:<16}      0x{x:04}   0x{x:04}  0x{x:08}  0x{x:08}  0x{x:08} \n",
            .{ ring_position, order_id, autoinc_address, station_address, info.vendor_id, info.product_code, info.revision_number },
        );
    }
    try writer.print("\n", .{});
}

fn printSubdeviceDetails(
    writer: anytype,
    port: *gcat.Port,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
    ring_position: u16,
) !void {
    const autoinc_address: u16 = gcat.SubDevice.autoincAddressFromRingPos(ring_position);
    const station_address: u16 = gcat.SubDevice.stationAddressFromRingPos(ring_position);

    const info = try gcat.sii.readSubdeviceInfoCompact(
        port,
        station_address,
        recv_timeout_us,
        eeprom_timeout_us,
    );

    const cat_general = try gcat.sii.readGeneralCatagory(
        port,
        station_address,
        recv_timeout_us,
        eeprom_timeout_us,
    );

    var name: []const u8 = "";
    var order_id: []const u8 = "";
    var group: []const u8 = "";
    if (cat_general) |general| {
        if (try gcat.sii.readSIIString(
            port,
            station_address,
            general.name_idx,
            recv_timeout_us,
            eeprom_timeout_us,
        )) |name_string| {
            name = name_string.slice();
        }
        if (try gcat.sii.readSIIString(
            port,
            station_address,
            general.order_idx,
            recv_timeout_us,
            eeprom_timeout_us,
        )) |order_id_string| {
            order_id = order_id_string.slice();
        }
        if (try gcat.sii.readSIIString(
            port,
            station_address,
            general.group_idx,
            recv_timeout_us,
            eeprom_timeout_us,
        )) |group_string| {
            group = group_string.slice();
        }
    }
    try writer.print("==================================\n", .{});
    try writer.print("=   {d}: {s:^16} 0x{x:04}   =\n", .{ ring_position, order_id, station_address });
    try writer.print("==================================\n", .{});
    // strings
    try writer.print("Order ID: {s}\n", .{order_id});
    try writer.print("Name:     {s}\n", .{name});
    try writer.print("Group:    {s}\n", .{group});
    try writer.print("\n", .{});

    // position
    try writer.print("Ring position:            {d:>5}\n", .{ring_position});
    try writer.print("Auto-increment address:  0x{x:04}\n", .{autoinc_address});
    try writer.print("Station address:         0x{x:04}\n\n", .{station_address});

    // identity
    try writer.print("Vendor ID:               0x{x:08}\n", .{info.vendor_id});
    try writer.print("Product code:            0x{x:08}\n", .{info.product_code});
    try writer.print("Revision number:         0x{x:08}\n", .{info.revision_number});
    try writer.print("Serial number:           0x{x:08}\n", .{info.serial_number});
    try writer.print("\n", .{});

    // supported protocols
    try writer.print("Supported mailbox protocols: ", .{});

    const has_mailbox = info.mbx_protocol.AoE or
        info.mbx_protocol.EoE or
        info.mbx_protocol.CoE or
        info.mbx_protocol.FoE or
        info.mbx_protocol.SoE or
        info.mbx_protocol.VoE;

    if (info.mbx_protocol.AoE) try writer.print("AoE ", .{});
    if (info.mbx_protocol.EoE) try writer.print("EoE ", .{});
    if (info.mbx_protocol.CoE) try writer.print("CoE ", .{});
    if (info.mbx_protocol.FoE) try writer.print("FoE ", .{});
    if (info.mbx_protocol.SoE) try writer.print("SoE ", .{});
    if (info.mbx_protocol.VoE) try writer.print("VoE ", .{});
    if (!has_mailbox) {
        try writer.print("None\n", .{});
    } else {
        try writer.print("\n", .{});
    }
    if (has_mailbox) {
        try writer.print("Default mailbox configuration:\n", .{});
        try writer.print(
            "    Mailbox out: offset: 0x{x:04} size: {}\n",
            .{ info.std_recv_mbx_offset, info.std_recv_mbx_size },
        );
        try writer.print(
            "    Mailbox in:  offset: 0x{x:04} size: {}\n",
            .{ info.std_send_mbx_offset, info.std_send_mbx_size },
        );
    }

    if (info.mbx_protocol.FoE) {
        try writer.print("Bootstrap mailbox configuration:\n", .{});
        try writer.print(
            "    Mailbox out: offset: 0x{x:04} size: {}\n",
            .{ info.bootstrap_recv_mbx_offset, info.bootstrap_recv_mbx_size },
        );
        try writer.print(
            "    Mailbox in:  offset: 0x{x:04} size: {}\n",
            .{ info.bootstrap_send_mbx_offset, info.bootstrap_send_mbx_size },
        );
    }
    try writer.print("\n", .{});
    if (cat_general) |general| {
        try writer.print("SII Catagory General:\n", .{});
        if (info.mbx_protocol.CoE) {
            try writer.print("    CoE Details:\n", .{});
            inline for (std.meta.fields(gcat.sii.CoEDetails)) |field| {
                if (comptime std.mem.eql(u8, field.name, "reserved")) continue;
                try writer.print("        {s:<26}  {:>5}\n", .{ field.name, @field(general.coe_details, field.name) });
            }
        }
        if (info.mbx_protocol.FoE) {
            try writer.print("    FoE Details:\n", .{});
            inline for (std.meta.fields(gcat.sii.FoEDetails)) |field| {
                if (comptime std.mem.eql(u8, field.name, "reserved")) continue;
                try writer.print("        {s:<26}  {:>5}\n", .{ field.name, @field(general.foe_details, field.name) });
            }
        }
        if (info.mbx_protocol.EoE) {
            try writer.print("    EoE Details:\n", .{});
            inline for (std.meta.fields(gcat.sii.EoEDetails)) |field| {
                if (comptime std.mem.eql(u8, field.name, "reserved")) continue;
                try writer.print("        {s:<26}  {:>5}\n", .{ field.name, @field(general.eoe_details, field.name) });
            }
        }
        // flags
        try writer.print("    Flags:\n", .{});
        inline for (std.meta.fields(gcat.sii.Flags)) |field| {
            if (comptime std.mem.eql(u8, field.name, "reserved")) continue;
            try writer.print("        {s:<26}  {:>5}\n", .{ field.name, @field(general.flags, field.name) });
        }
        if (general.flags.identity_physical_memory) {
            try writer.print("    ID Switch Phys Mem Addr: 0x{x}\n", .{general.physical_memory_address});
        }
    }

    const sm_catagory = try gcat.sii.readSMCatagory(port, station_address, recv_timeout_us, eeprom_timeout_us);
    if (sm_catagory.len > 0) {
        try writer.print("SII Catagory Sync Managers:\n", .{});
        for (sm_catagory.slice(), 0..) |sm, i| {
            try writer.print("    SM Index: {}\n", .{i});
            try writer.print("        type: {s}\n", .{std.enums.tagName(gcat.sii.SyncMType, sm.syncM_type) orelse "INVALID"});
            try writer.print("        physical start addr: 0x{x}\n", .{sm.physical_start_address});
            try writer.print("        length: {}\n", .{sm.length});
            try writer.print("            control:\n", .{});
            inline for (std.meta.fields(gcat.esc.SyncManagerControlRegister)) |field| {
                if (comptime std.mem.eql(u8, field.name, "reserved")) continue;
                try writer.print("                {s:<26}  {:<5}\n", .{ field.name, @field(sm.control, field.name) });
            }
            try writer.print("            status:\n", .{});
            inline for (std.meta.fields(gcat.esc.SyncManagerActivateRegister)) |field| {
                if (comptime std.mem.eql(u8, field.name, "reserved")) continue;
                try writer.print("                {s:<26}  {:<5}\n", .{ field.name, @field(sm.status, field.name) });
            }
            try writer.print("            enable:\n", .{});
            inline for (std.meta.fields(gcat.sii.EnableSyncMangager)) |field| {
                if (comptime std.mem.eql(u8, field.name, "reserved")) continue;
                try writer.print("                {s:<26}  {:<5}\n", .{ field.name, @field(sm.enable_sync_manager, field.name) });
            }
        }
    }

    try writer.print("\n", .{});
}

fn printSubdeviceSIIPDOs(
    writer: anytype,
    port: *gcat.Port,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
    station_address: u16,
) !void {
    const input_pdos_bit_length = try gcat.sii.readPDOBitLengths(
        port,
        station_address,
        .input,
        recv_timeout_us,
        eeprom_timeout_us,
    );

    const output_pdos_bit_length = try gcat.sii.readPDOBitLengths(
        port,
        station_address,
        .output,
        recv_timeout_us,
        eeprom_timeout_us,
    );

    if (output_pdos_bit_length == 0 and input_pdos_bit_length == 0) {
        try writer.print("SII Process Data Information: None\n", .{});
        return;
    } else {
        try writer.print("SII Process Data Information:\n", .{});
    }

    try writer.print("    Inputs bit length:  {d:>5}\n", .{input_pdos_bit_length});
    try writer.print("    Outputs bit length: {d:>5}\n", .{output_pdos_bit_length});
    try writer.print("\n", .{});

    const input_pdos = try gcat.sii.readPDOs(
        port,
        station_address,
        .input,
        recv_timeout_us,
        eeprom_timeout_us,
    );

    const output_pdos = try gcat.sii.readPDOs(
        port,
        station_address,
        .output,
        recv_timeout_us,
        eeprom_timeout_us,
    );

    if (input_pdos.len != 0) {
        try writer.print("SII Input PDOs:\n", .{});
        try printPDOTable(writer, input_pdos, port, station_address, recv_timeout_us, eeprom_timeout_us);
        try writer.print("\n", .{});
    }

    if (output_pdos.len != 0) {
        try writer.print("SII Output PDOs:\n", .{});
        try printPDOTable(writer, output_pdos, port, station_address, recv_timeout_us, eeprom_timeout_us);
        try writer.print("\n", .{});
    }
}

fn printPDOTable(
    writer: anytype,
    pdos: gcat.sii.PDOs,
    port: *gcat.Port,
    station_address: u16,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
) !void {
    const pdo_slice: []const gcat.sii.PDO = pdos.slice();
    if (pdo_slice.len > 0) {
        try writer.print("Index    SM Bits  Type              Name \n", .{});
        try writer.print("----------------------------------------------------------------------------------\n", .{});
    }
    for (pdo_slice) |pdo| {
        var pdo_name: []const u8 = "";
        const maybe_name = try gcat.sii.readSIIString(port, station_address, pdo.header.name_idx, recv_timeout_us, eeprom_timeout_us);
        if (maybe_name) |name| pdo_name = name.slice();
        try writer.print("0x{x:04}  {d:>3}    -  -                 {s:<64}\n", .{ pdo.header.index, pdo.header.syncM, pdo_name });

        const entries_slice: []const gcat.sii.PDO.Entry = pdo.entries.slice();
        for (entries_slice) |entry| {
            var entry_name: []const u8 = "";
            const maybe_name2 = try gcat.sii.readSIIString(port, station_address, entry.name_idx, recv_timeout_us, eeprom_timeout_us);
            if (maybe_name2) |name2| entry_name = name2.slice();
            try writer.print("     -    -  {d:>3}  {s:<16}  {s:<64}\n", .{
                entry.bit_length,
                std.enums.tagName(gcat.mailbox.coe.DataTypeArea, @enumFromInt(entry.data_type)) orelse "-",
                entry_name,
            });
        }
    }
}
fn printSubdeviceCoePDOs(
    writer: anytype,
    port: *gcat.Port,
    recv_timeout_us: u32,
    mbx_timeout_us: u32,
    subdevice: *gcat.SubDevice,
) !void {
    const coe_info = &(subdevice.runtime_info.coe orelse return);
    try writer.print("COE PDO Assignment:\n", .{});
    const station_address = gcat.SubDevice.stationAddressFromRingPos(subdevice.runtime_info.ring_position);
    const cnt = &coe_info.cnt;
    const mailbox_config = coe_info.config;

    const sm_comms = try gcat.mailbox.coe.readSMComms(port, station_address, recv_timeout_us, mbx_timeout_us, cnt, mailbox_config);

    for (sm_comms.slice(), 0..) |sm_comm, sm_idx| {
        try writer.print("    Sync Manager: {}, type: {s}\n", .{ sm_idx, std.enums.tagName(gcat.mailbox.coe.SMComm, sm_comm) orelse "Invalid SM Comm Type" });
    }
    try writer.print("PDO Index  SM Bits  Mapped Index\n", .{});
    try writer.print("----------------------------------------------\n", .{});

    for (sm_comms.slice(), 0..) |_, sm_idx| {
        const sm_pdo_assignment = gcat.mailbox.coe.readSMChannel(port, station_address, recv_timeout_us, mbx_timeout_us, cnt, mailbox_config, @intCast(sm_idx)) catch |err| switch (err) {
            error.Aborted => continue,
            else => |err2| return err2,
        };

        for (sm_pdo_assignment.slice()) |pdo_index| {
            const pdo_mapping = try gcat.mailbox.coe.readPDOMapping(port, station_address, recv_timeout_us, mbx_timeout_us, cnt, mailbox_config, pdo_index);
            try writer.print("0x{x:04}    {d:>3}  {d:>3}  -\n", .{ pdo_index, sm_idx, pdo_mapping.bitLength() });
            for (pdo_mapping.entries.slice()) |entry| {
                if (entry.isGap()) {
                    try writer.print("               {d:>3}  PADDING\n", .{entry.bit_length});
                } else {
                    try writer.print("               {d:>3}  0x{x:04}:{x:02}\n", .{ entry.bit_length, entry.index, entry.subindex });
                }
            }
        }
    }

    // const mapping = try gcat.mailbox.coe.readPDOMapping(
    //     port,
    //     gcat.SubDevice.stationAddressFromRingPos(subdevice.runtime_info.ring_position),
    //     recv_timeout_us,
    //     mbx_timeout_us,
    //     &subdevice.runtime_info.coe.?.cnt,
    //     subdevice.runtime_info.coe.?.config,
    //     0x1600,
    // );
    // try writer.print("mapping: {}\n", .{mapping});
}
