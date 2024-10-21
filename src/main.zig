const std = @import("std");

const flags = @import("flags");
const gcat = @import("gatorcat");

pub const std_options = .{
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

    // try std.json.stringify(
    //     parsed_args,
    //     .{ .whitespace = .indent_2 },
    //     std.io.getStdOut().writer(),
    // );

    switch (parsed_args.command) {
        .scan => |scan_args| {
            var port = try gcat.nic.Port.init(scan_args.ifname);
            defer port.deinit();

            try scan(
                &port,
                scan_args.recv_timeout_us,
                scan_args.eeprom_timeout_us,
                scan_args.INIT_timeout_us,
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
            ifname: []const u8,
            recv_timeout_us: u32 = 10_000,
            eeprom_timeout_us: u32 = 10_000,
            INIT_timeout_us: u32 = 5_000_000,
            pub const descriptions = .{
                .ifname = "Network interface to use for the bus scan.",
                .recv_timeout_us = "Frame receive timeout in microseconds.",
                .eeprom_timeout_us = "SII EEPROM timeout in microseconds.",
                .INIT_timeout_us = "state transition to INIT timeout in microseconds.",
            };
        },
    },
};

fn scan(
    port: *gcat.nic.Port,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
    INIT_timeout_us: u32,
) !void {
    var scanner = gcat.Scanner.init(port, .{ .eeprom_timeout_us = eeprom_timeout_us, .recv_timeout_us = recv_timeout_us });
    var writer = std.io.getStdOut().writer();

    const num_subdevices = try scanner.countSubdevices();
    try writer.print("Detected {} subdevices.\n", .{num_subdevices});

    try scanner.busINIT(INIT_timeout_us, num_subdevices);
    try writer.print("Successfully reached INIT.\n", .{});

    try scanner.assignStationAddresses(num_subdevices);
    try writer.print("Successfully assigned station addresses.\n", .{});
    try writer.print("\n", .{});

    // summary table
    try printBusSummary(writer, port, recv_timeout_us, eeprom_timeout_us, num_subdevices);
    // detailed info on each subdevice
    for (0..num_subdevices) |i| {
        try printSubdeviceDetails(writer, port, recv_timeout_us, eeprom_timeout_us, @intCast(i));
        try printSubdevicePDOs(
            writer,
            port,
            recv_timeout_us,
            eeprom_timeout_us,
            gcat.MainDevice.calc_station_addr(@intCast(i)),
        );
    }
}

fn printBusSummary(
    writer: anytype,
    port: *gcat.nic.Port,
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
        const autoinc_address: u16 = gcat.MainDevice.calc_autoinc_addr(ring_position);
        const station_address: u16 = gcat.MainDevice.calc_station_addr(ring_position);

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
    port: *gcat.nic.Port,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
    ring_position: u16,
) !void {
    const autoinc_address: u16 = gcat.MainDevice.calc_autoinc_addr(ring_position);
    const station_address: u16 = gcat.MainDevice.calc_station_addr(ring_position);

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
}

fn printSubdevicePDOs(
    writer: anytype,
    port: *gcat.nic.Port,
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
        try writer.print("Process Data: None\n", .{});
        return;
    } else {
        try writer.print("Process Data:\n", .{});
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
        try writer.print("Input PDOs:\n", .{});
        try printPDOTable(writer, input_pdos, port, station_address, recv_timeout_us, eeprom_timeout_us);
        try writer.print("\n", .{});
    }

    if (output_pdos.len != 0) {
        try writer.print("Output PDOs:\n", .{});
        try printPDOTable(writer, output_pdos, port, station_address, recv_timeout_us, eeprom_timeout_us);
        try writer.print("\n", .{});
    }
}

fn printPDOTable(
    writer: anytype,
    pdos: gcat.sii.PDOs,
    port: *gcat.nic.Port,
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
