const std = @import("std");
const assert = std.debug.assert;

pub const MainDevice = @import("MainDevice.zig");
pub const SubDevice = @import("SubDevice.zig");
pub const nic = @import("nic.zig");
pub const mailbox = @import("mailbox.zig");
pub const wire = @import("wire.zig");
pub const ENI = @import("ENI.zig");
pub const sii = @import("sii.zig");
pub const commands = @import("commands.zig");
pub const Scanner = @import("Scanner.zig");
pub const telegram = @import("telegram.zig");
pub const Port = @import("Port.zig");
pub const pdi = @import("pdi.zig");

pub fn subdevicesFromENI(comptime eni: ENI) [eni.subdevices.len]SubDevice {
    assert(eni.subdevices.len <= max_subdevices);
    var subdevices: [eni.subdevices.len]SubDevice = undefined;
    for (&subdevices, 0..) |*subdevice, i| {
        subdevice.* = SubDevice.init(eni.subdevices[i], @intCast(i));
    }
    return subdevices;
}

pub const max_subdevices = 65536;

test {
    std.testing.refAllDecls(@This());
}
