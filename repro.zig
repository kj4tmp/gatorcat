const std = @import("std");

test "rotl u0" {
    try std.testing.expectEqual(0, std.math.rotl(@Type(.{ .int = .{ .signedness = .unsigned, .bits = 0 } }), 0, 3));
}
