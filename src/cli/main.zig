const std = @import("std");
const builtin = @import("builtin");

const flags = @import("flags");
const gcat = @import("gatorcat");

const benchmark = @import("benchmark.zig");
const scan = @import("scan.zig");

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
            try scan.scan(scan_args);
        },
        .benchmark => |benchmark_args| {
            try benchmark.benchmark(benchmark_args);
        },
        .read_eeprom => |read_eeprom_args| {
            var raw_socket = switch (builtin.target.os.tag) {
                .linux => try gcat.nic.RawSocket.init(read_eeprom_args.ifname),
                .windows => try gcat.nic.WindowsRawSocket.init(read_eeprom_args.ifname),
                else => @compileError("unsupported target os"),
            };
            defer raw_socket.deinit();

            var port = gcat.Port.init(raw_socket.linkLayer(), .{});
            try port.ping(read_eeprom_args.recv_timeout_us);
            try read_eeprom(
                gpa.allocator(),
                &port,
                read_eeprom_args.ring_position,
                read_eeprom_args.recv_timeout_us,
                read_eeprom_args.eeprom_timeout_us,
                read_eeprom_args.INIT_timeout_us,
                read_eeprom_args.out,
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
        scan: scan.Args,
        benchmark: benchmark.Args,
        read_eeprom: struct {
            ifname: [:0]const u8,
            ring_position: u16,
            recv_timeout_us: u32 = 10_000,
            eeprom_timeout_us: u32 = 10_000,
            format: enum { bin } = .bin,
            out: ?[:0]const u8,
            INIT_timeout_us: u32 = 5_000_000,

            pub const descriptions = .{
                .ifname = "Network interface to use for contacting the subdevice (e.g. \"eth0\").",
                .ring_position = "Subdevice position in the ring to read the EEPROM from.",
                .recv_timeout_us = "Frame receive timeout in microseconds.",
                .eeprom_timeout_us = "SII EEPROM timeout is microseconds.",
                .format = "Output format.",
                .out = "Output file name.",
                .INIT_timeout_us = "INIT state change timeout in microseconds.",
            };
        },

        pub const descriptions = .{
            .scan = "Scan the EtherCAT bus and print information about the subdevices.",
            .benchmark = "Benchmark the performance of the EtherCAT bus.",
        };
    },
};

fn read_eeprom(
    allocator: std.mem.Allocator,
    port: *gcat.Port,
    ring_position: u16,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
    INIT_timeout_us: u32,
    out_file_name: ?[:0]const u8,
) !void {
    var scanner = gcat.Scanner.init(port, .{ .eeprom_timeout_us = eeprom_timeout_us, .recv_timeout_us = recv_timeout_us });
    var writer = std.io.getStdOut().writer();

    const num_subdevices = try scanner.countSubdevices();
    try writer.print("Detected {} subdevices.\n", .{num_subdevices});

    try scanner.busInit(INIT_timeout_us, num_subdevices);
    try writer.print("Successfully reached INIT.\n", .{});

    try scanner.assignStationAddresses(num_subdevices);
    try writer.print("Successfully assigned station addresses.\n", .{});

    const station_address = gcat.SubDevice.stationAddressFromRingPos(ring_position);
    try writer.print("Reading EEPROM of ring position: {}, station address: {}\n", .{ ring_position, station_address });

    const eeprom_info = try gcat.sii.readSubdeviceInfo(
        port,
        station_address,
        recv_timeout_us,
        eeprom_timeout_us,
    );

    const sii_byte_length: u64 = (@as(u64, eeprom_info.size) + 1) * 1024 / 8;
    try writer.print("Found EEPROM size: {} KiBit ({} bytes).\n", .{ eeprom_info.size + 1, sii_byte_length });

    var sii_stream = gcat.sii.SIIStream.init(
        port,
        station_address,
        0,
        recv_timeout_us,
        eeprom_timeout_us,
    );

    const sii_reader = sii_stream.reader();
    var limited_reader = std.io.limitedReader(sii_reader, sii_byte_length);
    const reader = limited_reader.reader();

    try writer.print("Reading EEPROM...\n", .{});
    const eeprom_content = try allocator.alloc(u8, sii_byte_length);
    defer allocator.free(eeprom_content);
    try reader.readNoEof(eeprom_content);

    try writer.print("EEPROM Content:\n", .{});
    for (eeprom_content, 0..) |content, i| {
        try writer.print("{x:02}", .{content});
        if (i % 16 == 15 and i % 32 != 0) {
            try writer.writeByte(' ');
        }
        if (i % 32 == 31) {
            try writer.writeByte('\n');
        }
    }
    try writer.writeByte('\n');

    // TODO: file output
    if (out_file_name) |file_name| {
        try writer.print("Writing eeprom contents to {s} ...\n", .{file_name});
        // const cwd = std.fs.cwd();
        // const absolute_path = cwd.writeFile(.{.})
        // const path = std.fs.
        // try std.fs.cre
    }
}
