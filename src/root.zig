const std = @import("std");
const testing = std.testing;

pub const esc = @import("esc.zig");
pub const telegram = @import("telegram.zig");
pub const nic = @import("nic.zig");

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}

test {
    // reference all public declarations so
    // the tests inside them will run
    std.testing.refAllDecls(@This());
}
