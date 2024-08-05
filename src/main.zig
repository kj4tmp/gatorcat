const std = @import("std");

const commands = @import("commands.zig");
const nic = @import("nic.zig");
const MainDevice = @import("maindevice.zig").MainDevice;

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const allocator = gpa.allocator();
    // defer {
    //     const deinit_status = gpa.deinit();
    //     //fail test; can't try in defer as defer is executed after we return
    //     if (deinit_status == .leak) {
    //         std.debug.print("leaked!", .{});
    //     }
    // }
    var port = try nic.Port.init("enx00e04c68191a");
    defer port.deinit();

    var main_device = MainDevice.init(
        &port,
        .{ .timeout_recv_us = 2000 },
    );

    const wkc = try main_device.bus_init();

    std.log.warn("found {} subdevices", .{wkc});
}
