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

    // process_data: ProcessData,

    /// Autoconfigure strategy
    auto_config: enum { auto } = .auto,

    // const ProcessData = struct {
    //     inputs_bit_length: u32 = 0,
    //     outputs_bit_length: u32 = 0,
    //     auto_config: AutoConfig,

    //     const AutoConfig = union(enum) {
    //         none: void,
    //         sii: void,
    //         coe: void,
    //     };
    // };
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

pub const ProcessImageStats = struct {
    input_bytes: u32,
    output_bytes: u32,
};

pub fn processImageSize(self: *const ENI) u32 {
    const stats = self.processImageStats();
    return stats.input_bytes + stats.output_bytes;
}

pub fn processImageStats(self: *const ENI) ProcessImageStats {
    // each subdevices will be given a byte aligned area for inputs
    // and a byte aligned area for outputs.
    var input_bytes: u32 = 0;
    var output_bytes: u32 = 0;
    for (self.subdevices) |subdevice_config| {
        input_bytes += (subdevice_config.inputs_bit_length + 7) / 8;
        output_bytes += (subdevice_config.outputs_bit_length + 7) / 8;
    }
    return ProcessImageStats{ .input_bytes = input_bytes, .output_bytes = output_bytes };
}

test {
    std.testing.refAllDecls(@This());
}
