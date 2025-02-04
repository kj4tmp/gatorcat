//! Serilization and deserialization utilities specific to EtherCAT.

const std = @import("std");
const assert = std.debug.assert;

const native_endian = @import("builtin").target.cpu.arch.endian();

pub fn packedSize(comptime T: type) comptime_int {
    comptime assert(isECatPackable(T));
    return @divExact(@bitSizeOf(T), 8);
}

// TODO: check recursively for struct fields that are enums?
pub fn isECatPackable(comptime T: type) bool {
    if (@bitSizeOf(T) % 8 != 0) return false;
    return switch (@typeInfo(T)) {
        .@"struct" => |_struct| blk: {
            // must be a packed struct
            break :blk (_struct.layout == .@"packed");
        },
        .int, .float => true,
        .@"union" => |_union| blk: {
            // must be a packed union
            break :blk (_union.layout == .@"packed");
        },
        .@"enum" => |_enum| blk: {
            // TODO: check enum cannot contain invalid values after bitcast
            // i.e. must be non-exhaustive or represent all values of
            // backing integer.
            break :blk !_enum.is_exhaustive;
        },
        else => false,
    };
}

pub fn eCatFromPackToWriter(pack: anytype, writer: anytype) !void {
    comptime assert(isECatPackable(@TypeOf(pack)));
    var bytes = eCatFromPack(pack);
    try writer.writeAll(&bytes);
}

/// convert a packed struct to bytes that can be sent via ethercat
///
/// the packed struct must have bitwidth that is a multiple of 8
pub fn eCatFromPack(pack: anytype) [@divExact(@bitSizeOf(@TypeOf(pack)), 8)]u8 {
    comptime assert(isECatPackable(@TypeOf(pack)));
    var bytes: [@divExact(@bitSizeOf(@TypeOf(pack)), 8)]u8 = undefined;
    switch (native_endian) {
        .little => {
            if (@typeInfo(@TypeOf(pack)) == .@"enum") {
                bytes = @bitCast(@as(@typeInfo(@TypeOf(pack)).@"enum".tag_type, @intFromEnum(pack)));
            } else {
                bytes = @bitCast(pack);
            }
        },
        .big => {
            if (@typeInfo(@TypeOf(pack)) == .@"enum") {
                bytes = @bitCast(@as(@typeInfo(@TypeOf(pack)).@"enum".tag_type, @intFromEnum(pack)));
            } else {
                bytes = @bitCast(pack);
            }
            std.mem.reverse(u8, &bytes);
        },
    }
    return bytes;
}

pub fn zerosFromPack(comptime T: type) [@divExact(@bitSizeOf(T), 8)]u8 {
    comptime assert(isECatPackable(T));
    return std.mem.zeroes([@divExact(@bitSizeOf(T), 8)]u8);
}

test "eCatFromPack" {
    const Command = packed struct(u8) {
        flag: bool = true,
        reserved: u7 = 0,
    };
    try std.testing.expectEqual(
        [_]u8{1},
        eCatFromPack(Command{}),
    );

    const Command2 = packed struct(u16) {
        flag: bool = true,
        reserved: u7 = 0,
        num: u8 = 7,
    };
    try std.testing.expectEqual(
        [_]u8{ 1, 7 },
        eCatFromPack(Command2{}),
    );

    const Command3 = packed struct(u24) {
        flag: bool = true,
        reserved: u7 = 0,
        num: u16 = 0x1122,
    };
    try std.testing.expectEqual(
        [_]u8{ 1, 0x22, 0x11 },
        eCatFromPack(Command3{}),
    );

    const Command4 = packed struct(u32) {
        flag: bool = true,
        reserved: u7 = 0,
        num: u16 = 0x1122,
        num2: u5 = 0x03,
        num3: u3 = 0,
    };
    try std.testing.expectEqual(
        [_]u8{ 1, 0x22, 0x11, 0x03 },
        eCatFromPack(Command4{}),
    );
    const Command5 = packed struct(u40) {
        flag: bool = true,
        reserved: u7 = 0,
        num: u16 = 0x1122,
        num2: u5 = 0x03,
        num3: u3 = 0,
        num4: u8 = 0xAB,
    };
    try std.testing.expectEqual(
        [_]u8{ 1, 0x22, 0x11, 0x03, 0xAB },
        eCatFromPack(Command5{}),
    );

    const command_enum: enum(u16) { zero, one, _ } = .one;
    try std.testing.expectEqual(
        [_]u8{ 0x01, 0x00 },
        eCatFromPack(command_enum),
    );
}

/// Read a packed struct, int, or float from a reader containing
/// EtherCAT (little endian) data into host endian representation.
pub fn packFromECatReader(comptime T: type, reader: anytype) !T {
    comptime assert(isECatPackable(T));
    var bytes: [@divExact(@bitSizeOf(T), 8)]u8 = undefined;
    try reader.readNoEof(&bytes);
    return packFromECat(T, bytes);
}

test packFromECatReader {
    const bytes = [_]u8{ 0, 1, 2 };
    var fbs = std.io.fixedBufferStream(&bytes);
    const reader = fbs.reader();
    const Pack = packed struct(u24) {
        a: u8,
        b: u8,
        c: u8,
    };
    const expected_pack = Pack{ .a = 0, .b = 1, .c = 2 };
    const actual_pack = packFromECatReader(Pack, reader);

    try std.testing.expectEqualDeep(expected_pack, actual_pack);
}

/// Convert little endian packed bytes from EtherCAT to host representation.
///
/// Supports enums, packed structs, and most primitive types. All most have
/// bitlength divisible by 8.
pub fn packFromECat(comptime T: type, ecat_bytes: [@divExact(@bitSizeOf(T), 8)]u8) T {
    comptime assert(isECatPackable(T));
    switch (native_endian) {
        .little => {
            if (@typeInfo(T) == .@"enum") {
                return @enumFromInt(@as(@typeInfo(T).@"enum".tag_type, @bitCast(ecat_bytes)));
            }
            return @bitCast(ecat_bytes);
        },
        .big => {
            var bytes_copy = ecat_bytes;
            std.mem.reverse(u8, &bytes_copy);
            if (@typeInfo(T) == .@"enum") {
                return @enumFromInt(@as(@typeInfo(T).@"enum".tag_type, @bitCast(ecat_bytes)));
            }
            return @bitCast(bytes_copy);
        },
    }
    unreachable;
}

pub fn packFromECatSlice(comptime T: type, ecat_bytes: []const u8) T {
    comptime assert(isECatPackable(T));
    assert(ecat_bytes.len == @divExact(@bitSizeOf(T), 8));
    var bytes: [@divExact(@bitSizeOf(T), 8)]u8 = undefined;
    @memcpy(&bytes, ecat_bytes);
    return packFromECat(T, bytes);
}

test "packFromECat" {
    const Command = packed struct(u8) {
        flag: bool = true,
        reserved: u7 = 0,
    };
    try std.testing.expectEqual(
        Command{},
        packFromECat(Command, [_]u8{1}),
    );

    const Command2 = packed struct(u16) {
        flag: bool = true,
        reserved: u7 = 0,
        num: u8 = 7,
    };
    try std.testing.expectEqual(
        Command2{},
        packFromECat(Command2, [_]u8{ 1, 7 }),
    );

    const Command3 = packed struct(u24) {
        flag: bool = true,
        reserved: u7 = 0,
        num: u16 = 0x1122,
    };
    try std.testing.expectEqual(
        Command3{},
        packFromECat(Command3, [_]u8{ 1, 0x22, 0x11 }),
    );

    const Command4 = packed struct(u32) {
        flag: bool = true,
        reserved: u7 = 0,
        num: u16 = 0x1122,
        num2: u5 = 0x03,
        num3: u3 = 0,
    };
    try std.testing.expectEqual(
        Command4{},
        packFromECat(Command4, [_]u8{ 1, 0x22, 0x11, 0x03 }),
    );
    const Command5 = packed struct(u40) {
        flag: bool = true,
        reserved: u7 = 0,
        num: u16 = 0x1122,
        num2: u5 = 0x03,
        num3: u3 = 0,
        num4: u8 = 0xAB,
    };
    try std.testing.expectEqual(
        Command5{},
        packFromECat(Command5, [_]u8{ 1, 0x22, 0x11, 0x03, 0xAB }),
    );
}

test {
    std.testing.refAllDecls(@This());
}
