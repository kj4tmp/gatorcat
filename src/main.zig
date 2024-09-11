const std = @import("std");

const flags = @import("flags");
const ecm = @import("ecm");
const nic = ecm.nic;
const MainDevice = ecm.MainDevice;

pub const std_options = .{
    // Set the log level to info
    .log_level = .warn,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var args = try std.process.argsWithAllocator(gpa.allocator());
    defer args.deinit();

    const parsed_args = flags.parse(&args, zecm, .{});

    try std.json.stringify(
        parsed_args,
        .{ .whitespace = .indent_2 },
        std.io.getStdOut().writer(),
    );

    // switch (parsed_args.command) {
    //     .scan => |scan_args| {
    //         var port = try nic.Port.init(scan_args.ifname);
    //         defer port.deinit();

    //         var main_device = MainDevice.init(
    //             &port,
    //             .{ .timeout_recv_us = 2000 },
    //             null,
    //         );

    //         _ = try main_device.bus_init();
    //     },
    // }
}

// CLI options
const zecm = struct {
    // Optional description of the program.
    pub const description =
        \\The Zig EtherCAT MainDevice CLI.
    ;
    // sub commands
    command: union(enum) {
        // scan bus
        scan: struct {
            ifname: []const u8,
            pub const descriptions = .{
                .ifname = "Network interface to use for the bus scan.",
            };
        },
    },
};
