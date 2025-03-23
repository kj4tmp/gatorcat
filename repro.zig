const std = @import("std");

pub const struct_z_owned_config_t = extern struct {
    _0: [1840]u8 = @import("std").mem.zeroes([1840]u8),
};
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();

    const allocator = arena.allocator();

    const config = try allocator.create(struct_z_owned_config_t);
    defer allocator.destroy(config);
}
