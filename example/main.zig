const std = @import("std");

const nic = @import("ecm").nic;
const MainDevice = @import("ecm").MainDevice;

pub const std_options = .{
    .log_level = .warn,
};

pub fn main() !void {
    var port = try nic.Port.init("enx00e04c68191a");
    defer port.deinit();

    var main_device = MainDevice.init(
        &port,
        .{ .timeout_recv_us = 2000 },
    );

    try main_device.scan();
}
