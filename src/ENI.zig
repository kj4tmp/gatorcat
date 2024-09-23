//! EtherCAT Network Information (ENI)
//!
//! The ENI defines the expected subdevices and bus topology.
//!
//! This is not fully spec-compliant (Ref: ETG 2100) since it is intended
//! to be simpler and easier to define.
//!
//! The ENI is constant, and will never be modified by the MainDevice.
const ENI = @This();

const sii = @import("sii.zig");

subdevices: []const SubDeviceConfiguration,

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
};

pub const CoEStartupParameter = struct {
    transition: Transition,
    timeout_us: u32,
    direction: Direction,
    index: u16,
    subindex: u8,
    data: []const u8,

    pub const Direction = enum {
        read,
        write,
    };
};

const Transition = enum {
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
