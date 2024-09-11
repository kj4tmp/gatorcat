const std = @import("std");

pub const MainDevice = @import("MainDevice.zig");
pub const SubDevice = @import("SubDevice.zig");
pub const nic = @import("nic.zig");

test {
    std.testing.refAllDeclsRecursive(@This());
}
