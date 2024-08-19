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

    switch (parsed_args.command) {
        .scan => |scan_args| {
            var port = try nic.Port.init(scan_args.ifname);
            defer port.deinit();

            var main_device = MainDevice.init(
                &port,
                .{ .timeout_recv_us = 2000 },
                null,
            );

            _ = try main_device.bus_init();
        },
    }
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

fn send_and_recv(*port: Port, data: []u8, timeout_us: u32) !u16 {
    
    // send data (ethernet frame) through a ring of subdevices, returning back to me on the same network interface
    try port.send(data)

    // recv the data back, modified by the devices.
    // we recv that data back into the "data" parameter so that
    // we can have a zero-allocation API (recv'd data is always the same size as sent data)
    // the devices that did something increment a counter in the frame that is used
    // as a basic check that everything is ok
    // this is called the working counter "wkc"

    const wkc: u16 = try port.recv_with_timeout(data, timeout_us)
    return wkc
}

test {

    // in this scenario, we don't care what the subdevices did to the frame
    // other than the working counter
    var byte: [1]u8 = .{1};
    const wkc = send_and_recv(&byte);

    if (wkc == 0) {
        // uh oh! maybe the ethernet cable broke or a subdevice lost power!
        // do something about it!
        handle_subdevice_error();
    }
}
