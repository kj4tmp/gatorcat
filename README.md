

zig annoyances

1. Cannot tell if my tests have run or not (even with --summary all)
2. Packed structs are not well described in the language reference
3. Where to I look for the implementation of flags.parse? root.zig? I don't know where
anything is!



zig wins

big endian archs tests:

1. sudo apt install qemu-system-ppc qemu-utils binfmt-support qemu-user-static
2. zig build -fqemu -Dtarget=powerpc64-linux test --summary all


Why do I need `comptime T: type` when `@typeOf` exists?

I'm writing a binary protocol to be sent over a network interface. I think I have found a way to represent the binary protocol largely as packed structs, so I came up with this basic serialization function to convert a packed struct to bytes to be sent. I know it is inefficent and not really zero copy, but it gets the job done.

1. is this the correct `generics` way to do it?
2. Does it feel a little redundant to anyone else that I need `comptime T: type`? Is this actually required to accomplish what I want?

```
/// convert a packed struct to bytes that can be sent via ethercat
/// 
/// the packed struct must have bitwidth that is a multiple of 8
pub fn eCatFromPack(comptime T: type, packed_struct: T) [@divExact(@bitSizeOf(T), 8)]u8 {
    comptime std.debug.assert(@typeInfo(T).Struct.layout == .@"packed"); // must be a packed struct
    var bytes: [@divExact(@bitSizeOf(T), 8)]u8 = undefined;

    switch (native_endian) {
        .little => {
            bytes = @bitCast(packed_struct);
        },
        .big => {
            bytes = @bitCast(packed_struct);
            std.mem.reverse(u8, &bytes);
        },
    }
    return bytes;
}

test "eCatFromPack" {
    const Command = packed struct(u8) {
        flag: bool = true,
        reserved: u7 = 0,
    };
    try std.testing.expectEqual(
        [_]u8{1},
        eCatFromPack(Command, Command{}),
    );

    const Command2 = packed struct(u16) {
        flag: bool = true,
        reserved: u7 = 0,
        num: u8 = 7,
    };
    try std.testing.expectEqual(
        [_]u8{1, 7},
        eCatFromPack(Command2, Command2{}),
    );

    const Command3 = packed struct(u24) {
        flag: bool = true,
        reserved: u7 = 0,
        num: u16 = 0x1122,
    };
    try std.testing.expectEqual(
        [_]u8{1, 0x22, 0x11},
        eCatFromPack(Command3, Command3{}),
    );

    const Command4 = packed struct(u32) {
        flag: bool = true,
        reserved: u7 = 0,
        num: u16 = 0x1122,
        num2: u5 = 0x03,
        num3: u3 = 0,
    };
    try std.testing.expectEqual(
        [_]u8{1, 0x22, 0x11, 0x03},
        eCatFromPack(Command4, Command4{}),
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
        [_]u8{1, 0x22, 0x11, 0x03, 0xAB},
        eCatFromPack(Command5, Command5{}),
    );
}
```