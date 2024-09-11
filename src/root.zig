const std = @import("std");

pub const MainDevice = @import("MainDevice.zig");

pub const nic = @import("nic.zig");

pub const config = @import("config.zig");
pub const sii = @import("sii.zig");
pub const mailbox = @import("mailbox.zig");

test {
    std.testing.refAllDeclsRecursive(@This());
}
