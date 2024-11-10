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

/// Subdevices in the order they appear in the ethercat ring (index 0 is first subdevice).
subdevices: []const SubDeviceConfiguration,

pub const SubDeviceConfiguration = struct {
    /// identity
    identity: sii.SubDeviceIdentity,

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
