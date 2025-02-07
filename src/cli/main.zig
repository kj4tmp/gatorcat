const std = @import("std");
const builtin = @import("builtin");

const flags = @import("flags");
const gcat = @import("gatorcat");

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
        scan: scan.ScanArgs,
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
