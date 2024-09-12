const std = @import("std");

pub const MainDevice = @import("MainDevice.zig");
pub const SubDevice = @import("SubDevice.zig");
pub const nic = @import("nic.zig");

pub const client = @import("coe/client.zig");
pub const coe = @import("coe/coe.zig");
pub const server = @import("coe/server.zig");
pub const mailbox = @import("mailbox.zig");

test {
    std.testing.refAllDeclsRecursive(@This());
}
