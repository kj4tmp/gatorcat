const std = @import("std");
const assert = std.debug.assert;
const builtin = @import("builtin");

const gcat = @import("gatorcat");

const eni = @import("network_config.zig").eni;

pub const std_options: std.Options = .{
    .log_level = .info,
};

pub fn main() !void {
    var raw_socket = switch (builtin.target.os.tag) {
        .linux => try gcat.nic.RawSocket.init("enx00e04c68191a"),
        .windows => try gcat.nic.WindowsRawSocket.init("\\Device\\NPF_{538CF305-6539-480E-ACD9-BEE598E7AE8F}"),
        else => @compileError("unsupported target os"),
    };
    defer raw_socket.deinit();
    var port = gcat.Port.init(raw_socket.networkAdapter(), .{});
    try port.ping(10000);

    const estimated_stack_usage = comptime gcat.MainDevice.estimateAllocSize(eni) + 8;
    var stack_memory: [estimated_stack_usage]u8 = undefined;
    var stack_fba = std.heap.FixedBufferAllocator.init(&stack_memory);

    var md = try gcat.MainDevice.init(
        stack_fba.allocator(),
        &port,
        .{ .recv_timeout_us = 20000, .eeprom_timeout_us = 10_000 },
        eni,
    );
    defer md.deinit(stack_fba.allocator());

    try md.busINIT(5_000_000);
    try md.busPREOP(10_000_000);
    md.busSAFEOP(10_000_000) catch |err| switch (err) {
        error.StateChangeTimeout => {
            std.debug.print(
                "{any}",
                .{
                    try gcat.mailbox.readMailboxIn(
                        &port,
                        0x1001,
                        10_000,
                        .{
                            .length = 128,
                            .start_addr = 4224,
                        },
                    ),
                },
            );
        },
        else => |err2| return err2,
    };
    try md.busOP(10_000_000);
}
