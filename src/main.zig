const std = @import("std");

const commands = @import("commands.zig");
const nic = @import("nic.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) {
            std.debug.print("leaked!", .{});
        }
    }
    var port = try nic.Port.init("enx00e04c68191a", allocator, .{});
    defer port.deinit();

    var data: [4]u8 = .{ 0, 0, 0, 0 };
    const wkc = try commands.BRD(
        &port,
        .{ .position = 0, .offset = 0 },
        data[0..],
        3000,
    );
    std.debug.print("wkc: {d}", .{wkc});

    std.debug.print("connected to port", .{});
}

test "socket permissions error" {
    const ETH_P_ETHERCAT: u16 = 0x88a4;
    const socket_result = std.posix.socket(
        std.posix.AF.PACKET,
        std.posix.SOCK.RAW,
        std.mem.nativeToBig(u32, ETH_P_ETHERCAT),
    );
    try std.testing.expect(socket_result == std.posix.SocketError.PermissionDenied);
}
