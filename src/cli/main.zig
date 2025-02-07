const std = @import("std");
const builtin = @import("builtin");

const flags = @import("flags");
const gcat = @import("gatorcat");

const benchmark = @import("benchmark.zig");
const read_eeprom = @import("read_eeprom.zig");
const scan = @import("scan.zig");

pub const std_options: std.Options = .{
    .log_level = .warn,
};

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
        read_eeprom: read_eeprom.Args,
        pub const descriptions = .{
            .scan = "Scan the EtherCAT bus and print information about the subdevices.",
            .benchmark = "Benchmark the performance of the EtherCAT bus.",
            .read_eeprom = "Read the eeprom of a subdevice.",
        };
    },
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
        .scan => |scan_args| try scan.scan(gpa.allocator(), scan_args),
        .benchmark => |benchmark_args| try benchmark.benchmark(benchmark_args),
        .read_eeprom => |read_eeprom_args| try read_eeprom.read_eeprom(gpa.allocator(), read_eeprom_args),
    }
}
