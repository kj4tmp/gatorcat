//! EtherCAT Network Information (ENI)
//!
//! The ENI defines the expected subdevices and bus topology.
//!
//! This is not fully spec-compliant (Ref: ETG 2100) since it is intended
//! to be simpler and easier to define.
//!
//! The ENI is constant, and will never be modified by the MainDevice.
const std = @import("std");

const coe = @import("mailbox.zig").coe;
const sii = @import("sii.zig");

const ENI = @This();

/// Subdevices in the order they appear in the ethercat ring (index 0 is first subdevice).
subdevices: []const SubDeviceConfiguration,

pub const SubDeviceConfiguration = struct {
    /// ex. "EL7031-0030"
    name: []const u8 = &.{},
    identity: sii.SubDeviceIdentity,
    /// SDO startup parameters
    startup_parameters: []const StartupParameter = &.{},
    /// Autoconfigure strategy
    auto_config: enum { auto } = .auto,
    /// Inputs w/r/t the maindevice, also called TxPDO's
    inputs: []const PDO = &.{},
    /// Outputs w/r/t the maindevice, also called the RxPDO's
    outputs: []const PDO = &.{},

    // TODO: subdevice groups
    group: u8 = 0,

    const PDO = struct {
        index: u16,
        entries: []const Entry,
        name: []const u8 = &.{},

        const Entry = struct {
            index: u16 = 0,
            subindex: u8 = 0,
            type: coe.DataTypeArea = .UNKNOWN,
            bits: u16,
            description: ?[]const u8 = null,
        };
    };

    pub fn inputsBitLength(self: SubDeviceConfiguration) u32 {
        var res: u32 = 0;
        for (self.inputs) |input| {
            for (input.entries) |entry| {
                res += entry.bits;
            }
        }
        return res;
    }

    pub fn outputsBitLength(self: SubDeviceConfiguration) u32 {
        var res: u32 = 0;
        for (self.outputs) |output| {
            for (output.entries) |entry| {
                res += entry.bits;
            }
        }
        return res;
    }
    pub const StartupParameter = struct {
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
    };
};

pub fn processImageSize(self: *const ENI) u32 {
    const stats = self.processImageStats();
    return stats.input_bytes + stats.output_bytes;
}

pub const ProcessImageStats = struct {
    input_bytes: u32,
    output_bytes: u32,
};

pub fn processImageStats(self: *const ENI) ProcessImageStats {
    // each subdevices will be given a byte aligned area for inputs
    // and a byte aligned area for outputs.
    var input_bytes: u32 = 0;
    var output_bytes: u32 = 0;
    for (self.subdevices) |subdevice_config| {
        input_bytes += (subdevice_config.inputsBitLength() + 7) / 8;
        output_bytes += (subdevice_config.outputsBitLength() + 7) / 8;
    }
    return ProcessImageStats{ .input_bytes = input_bytes, .output_bytes = output_bytes };
}

test {
    std.testing.refAllDecls(@This());
}
