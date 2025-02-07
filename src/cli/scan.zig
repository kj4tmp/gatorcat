const std = @import("std");
const builtin = @import("builtin");

const gcat = @import("gatorcat");

pub const Args = struct {
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
};

pub fn scan(allocator: std.mem.Allocator, args: Args) !void {
    var raw_socket = switch (builtin.target.os.tag) {
        .linux => try gcat.nic.RawSocket.init(args.ifname),
        .windows => try gcat.nic.WindowsRawSocket.init(args.ifname),
        else => @compileError("unsupported target os"),
    };
    defer raw_socket.deinit();

    var port2 = gcat.Port.init(raw_socket.linkLayer(), .{});
    const port = &port2;

    try port.ping(args.recv_timeout_us);

    const res: gcat.ENI = .{ .subdevices = &.{} };

    const subdevice_configs = std.ArrayList(gcat.ENI.SubDeviceConfiguration).init(allocator);
    defer subdevice_configs.deinit();

    var scanner = gcat.Scanner.init(port, .{ .eeprom_timeout_us = args.eeprom_timeout_us, .mbx_timeout_us = args.mbx_timeout_us, .recv_timeout_us = args.recv_timeout_us });

    const num_subdevices = try scanner.countSubdevices();
    try scanner.busInit(args.INIT_timeout_us, num_subdevices);

    for (0..num_subdevices) |i| {
        _ = try scanner.subdevicePREOP(args.PREOP_timeout_us, @intCast(i));
    }

    var std_out = std.io.getStdOut();
    try std.zon.stringify.serialize(res, .{ .emit_default_optional_fields = false }, std_out.writer());
    try std_out.writer().writeByte('\n');
}

pub fn scan2(args: Args) !void {
    var raw_socket = switch (builtin.target.os.tag) {
        .linux => try gcat.nic.RawSocket.init(args.ifname),
        .windows => try gcat.nic.WindowsRawSocket.init(args.ifname),
        else => @compileError("unsupported target os"),
    };
    defer raw_socket.deinit();

    var port2 = gcat.Port.init(raw_socket.linkLayer(), .{});
    var port = &port2;
    try port.ping(args.recv_timeout_us);

    var scanner = gcat.Scanner.init(port, .{ .eeprom_timeout_us = args.eeprom_timeout_us, .recv_timeout_us = args.recv_timeout_us });
    var writer = std.io.getStdOut().writer();

    const num_subdevices = try scanner.countSubdevices();
    try writer.print("Detected {} subdevices.\n", .{num_subdevices});

    try scanner.busInit(args.INIT_timeout_us, num_subdevices);
    try writer.print("Successfully reached INIT.\n", .{});

    try scanner.assignStationAddresses(num_subdevices);
    try writer.print("Successfully assigned station addresses.\n", .{});
    try writer.print("\n", .{});

    // summary table
    try printBusSummary(writer, port, args.recv_timeout_us, args.eeprom_timeout_us, num_subdevices);
    // detailed info on each subdevice
    if (args.ring_position) |position| {
        try printSubdeviceDetails(writer, port, args.recv_timeout_us, args.eeprom_timeout_us, @intCast(position));
        try printSubdeviceSIIPDOs(
            writer,
            port,
            args.recv_timeout_us,
            args.eeprom_timeout_us,
            gcat.SubDevice.stationAddressFromRingPos(@intCast(position)),
        );
        var subdevice = try scanner.subdevicePREOP(args.PREOP_timeout_us, position);
        try printSubdeviceCoePDOs(writer, port, args.recv_timeout_us, args.mbx_timeout_us, &subdevice);
    } else {
        for (0..num_subdevices) |i| {
            try printSubdeviceDetails(writer, port, args.recv_timeout_us, args.eeprom_timeout_us, @intCast(i));
            try printSubdeviceSIIPDOs(
                writer,
                port,
                args.recv_timeout_us,
                args.eeprom_timeout_us,
                gcat.SubDevice.stationAddressFromRingPos(@intCast(i)),
            );
            var subdevice = try scanner.subdevicePREOP(args.PREOP_timeout_us, @intCast(i));
            try printSubdeviceCoePDOs(writer, port, args.recv_timeout_us, args.mbx_timeout_us, &subdevice);
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

    const od_list_lengths = try gcat.mailbox.coe.readODListLengths(
        port,
        station_address,
        recv_timeout_us,
        mbx_timeout_us,
        cnt,
        mailbox_config,
    );
    try writer.print("od list lengths: {}\n", .{od_list_lengths});

    const od_list_all = try gcat.mailbox.coe.readODList(
        port,
        station_address,
        recv_timeout_us,
        mbx_timeout_us,
        cnt,
        mailbox_config,
        .all_objects,
    );
    try writer.print("od list lengths: {}\n", .{od_list_lengths});
    try writer.print("od list all (len: {}): {x}\n", .{ od_list_all.slice().len, od_list_all.slice() });

    for (od_list_all.slice()) |index| {
        const object_description = try gcat.mailbox.coe.readObjectDescription(
            port,
            station_address,
            recv_timeout_us,
            mbx_timeout_us,
            cnt,
            mailbox_config,
            index,
        );

        try writer.print("0x{x} :: {s} :: {} :: {}\n", .{ index, object_description.name.slice(), object_description.data_type, object_description.max_subindex });

        if (object_description.max_subindex > 0) {
            for (1..object_description.max_subindex) |subindex| {
                const entry_description = try gcat.mailbox.coe.readEntryDescription(
                    port,
                    station_address,
                    recv_timeout_us,
                    mbx_timeout_us,
                    cnt,
                    mailbox_config,
                    index,
                    @intCast(subindex),
                    .description_only,
                );
                try writer.print("      --- 0x{x}:{x} :: {} ::{s}\n", .{ index, subindex, entry_description.data_type, entry_description.data.slice() });
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
