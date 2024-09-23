const std = @import("std");

pub const MainDevice = @import("MainDevice.zig");
pub const SubDevice = @import("SubDevice.zig");
pub const nic = @import("nic.zig");
pub const mailbox = @import("mailbox.zig");
pub const wire = @import("wire.zig");
pub const ENI = @import("ENI.zig");
pub const sii = @import("sii.zig");

test {
    std.testing.refAllDeclsRecursive(@This());
}
