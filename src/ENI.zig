//! EtherCAT Network Information (ENI)
//!
//! The ENI defines the expected subdevices and bus topology.
//!
//! This is not fully spec-compliant (Ref: ETG 2100) since it is intended
//! to be simpler and easier to define.
//!
//! The ENI is constant, and will never be modified by the MainDevice.
const std = @import("std");
const sii = @import("sii.zig");

const ENI = @This();

subdevices: []const SubDeviceConfiguration,

/// get the size of the process image in bytes
pub fn processImageSize(self: *const ENI) u32 {
    return self.processImageInputsSize() + self.processImageOutputsSize();
}

pub fn processImageInputsSize(self: *const ENI) u32 {
    if (self.subdevices.len == 0) return 0;

    // each subdevices will be given a byte aligned area for inputs
    // and a byte aligned area for outputs.
    var bytes_used: u32 = 0;
    for (self.subdevices) |subdevice| {
        bytes_used += (subdevice.inputs_bit_length + 7) / 8;
    }
    return bytes_used;
}
pub fn processImageOutputsSize(self: *const ENI) u32 {
    if (self.subdevices.len == 0) return 0;

    // each subdevices will be given a byte aligned area for inputs
    // and a byte aligned area for outputs.
    var bytes_used: u32 = 0;
    for (self.subdevices) |subdevice| {
        bytes_used += (subdevice.outputs_bit_length + 7) / 8;
    }
    return bytes_used;
}

pub fn processImageOutputsLogicalStartAddr(self: *const ENI) u32 {
    return 0 + self.processImageInputsSize();
}

pub const SubDeviceConfiguration = struct {
    /// identity
    identity: sii.SubDeviceIdentity,

    /// unique station address
    /// TODO: figure out how to remove this / auto-assign it?
    station_address: u16,
    /// zero-indexed position in the ethercat ring.
    /// first subdevice is 0, next is 1, etc.
    ring_position: u16,

    /// Process image
    inputs_bit_length: u32 = 0,
    outputs_bit_length: u32 = 0,

    /// SDO startup parameters
    coe_startup_parameters: ?[]const CoEStartupParameter = null,

    /// Autoconfigure strategy
    auto_config: enum { none, sii } = .sii,
};

pub const CoEStartupParameter = struct {
    transition: Transition,
    timeout_us: u32,
    direction: Direction,
    index: u16,
    subindex: u8,
    complete_access: bool,
    data: []const u8,

    pub const Direction = enum {
        read,
        write,
    };
};

pub const Transition = enum {
    /// INIT -> PREOP
    IP,
    /// INIT -> SAFEOP
    PS,
    /// PREOP -> INIT
    PI,
    /// SAFEOP -> PREOP
    SP,
    /// SAFEOP -> OP
    SO,
    /// SAFEOP -> INIT
    SI,
    /// OP -> SAFEOP
    OS,
    /// OP -> PREOP
    OP,
    /// OP -> INIT
    OI,
    /// INIT -> BOOT
    IB,
    /// BOOT -> INIT
    BI,
    /// INIT -> INIT
    II,
    /// PREOP -> PREOP
    PP,
    /// SAFEOP -> SAFEOP
    SS,
};

test {
    std.testing.refAllDecls(@This());
}
