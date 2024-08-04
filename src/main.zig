const std = @import("std");

const commands = @import("commands.zig");
const nic = @import("nic.zig");

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

    var data: [4]u8 = .{ 0, 0, 0, 0 };
    const wkc = try commands.BRD(
        &port,
        .{ .position = 0, .offset = 0 },
        data[0..],
        10000,
    );
    std.log.debug("data: {x}", .{data});
    std.log.debug("wkc: {d}", .{wkc});
    // var data2: [4]u8 = .{ 0, 0, 0, 0 };
    // const wkc2 = try commands.BWR(
    //     &port,
    //     data2[0..],
    //     10000,
    // );
    // std.log.debug("data2: {x}", .{data2});
    // std.log.debug("wkc2: {d}", .{wkc2});
}

test "byteswap enum field" {
    const EtherType = enum(u16) {
        UDP_ETHERCAT = 0x8000,
        ETHERCAT = 0x88a4,
        // .. there are many more
    };

    const EthernetHeader = packed struct {
        dest_mac: u48,
        src_mac: u48,
        ether_type: u16,
    };

    var header: EthernetHeader = .{
        .dest_mac = 0xAAAA_AAAA_AAAA,
        .src_mac = 0xBBBB_BBBB_BBBB,
        .ether_type = @intFromEnum(EtherType.ETHERCAT),
    };

    std.mem.byteSwapAllFields(EthernetHeader, &header);
}

// test "header write" {
//     const EthernetHeader = packed struct(u112) {
//         dest_mac: u48,
//         src_mac: u48,
//         ether_type: u16,

//         comptime {
//             std.debug.assert(@sizeOf(@This()) == 112 / 8);
//         }
//     };

//     const header: EthernetHeader = .{
//         .dest_mac = 0xAABB_CCDD_EEFF,
//         .src_mac = 0x1122_3344_5566,
//         .ether_type = 0x88a4,
//     };

//     var buf: [64]u8 = std.mem.zeroes([64]u8);
//     var fbs = std.io.fixedBufferStream(&buf);
//     var writer = fbs.writer();
//     try writer.writeStructEndian(header, std.builtin.Endian.big);
//     std.log.warn("wrote: {x}", .{fbs.getWritten()});
//     // prints: { aa, bb, cc, dd, ee, ff, 11, 22, 33, 44, 55, 66, 88, a4, 0, 0 }
//     // the 0, 0 at the end should not be there!                          ^  ^ bad!!
//     try std.testing.expect(fbs.getWritten().len == 112 / 8);
// }
