pub const nic = @import("nic.zig");
pub const MainDevice = @import("maindevice.zig").MainDevice;
pub const BusConfiguration = @import("config.zig").BusConfiguration;
pub const SubDevice = @import("config.zig").SubDevice;
pub const SubDeviceRuntimeInfo = @import("config.zig").SubDeviceRuntimeInfo;

pub const SIIStream = @import("sii.zig").SIIStream;

pub const mailbox = @import("mailbox.zig");

const std = @import("std");

test {
    std.testing.refAllDeclsRecursive(@This());
}
