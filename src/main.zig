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

const native_endian = @import("builtin").target.cpu.arch.endian();

fn packed_struct_to_bytes_little(comptime T: type, packed_struct: T) [@divExact(@bitSizeOf(T), 8)]u8 {
    comptime std.debug.assert(@typeInfo(T).Struct.layout == .@"packed"); // must be a packed struct
    var bytes: [@divExact(@bitSizeOf(T), 8)]u8 = undefined;

    switch (native_endian) {
        .little => {
            bytes = @bitCast(packed_struct);
        },
        .big => {
            std.mem.writePackedInt(
                @typeInfo(T).Struct.backing_integer.?,
                &bytes,
                0,
                @bitCast(packed_struct),
                .little,
            );
        },
    }
    return bytes;
}

test "write packed struct" {
    const Command = packed struct(u16) {
        flag: bool,
        reserved: u7 = 0,
        num: u8,
    };

    const my_command = Command{
        .flag = true,
        .num = 7,
    };

    const command_bytes = packed_struct_to_bytes_little(
        Command,
        my_command,
    );

    try std.testing.expectEqual(
        [_]u8{ 1, 7 },
        command_bytes,
    );
}

test "mem layout packed struct" {
    const Pack = packed struct(u48) {
        num1: u16 = 0x1234,
        num2: u16 = 0x5678,
        num3: u9 = 0b1_00000000,
        num4: bool = true,
        pad: u6 = 0,
    };

    const memory: [6]u8 = @bitCast(Pack{});
    switch (native_endian) {
        .big => {
            try std.testing.expectEqual(
                [6]u8{ 0x03, 0x00, 0x56, 0x78, 0x12, 0x34 },
                memory,
            );
            std.log.warn("ran big endian test!", .{});
        },
        .little => {
            try std.testing.expectEqual(
                [6]u8{ 0x34, 0x12, 0x78, 0x56, 0x00, 0x03 },
                memory,
            );
            std.log.warn("ran little endian test!", .{});
        },
    }
}
