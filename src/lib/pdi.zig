//! Process Data Interface
//!
//! The process data image is the logical memory address space. Subdevices can read from and write to
//! the address space. The FMMUs in each subdevice govern the translation of the logical memory
//! address space to the physical memory address space and vice-versa.

const std = @import("std");
const assert = std.debug.assert;

const ENI = @import("ENI.zig");
const SubDevice = @import("SubDevice.zig");

pub const Direction = enum {
    /// subdevice writes data to image
    input,
    /// maindevice writes data to image
    output,
};

pub const LogicalMemoryArea = struct {
    start_addr: u32,
    bit_length: u32,
};

/// get the size of the process image in bytes
pub fn processImageSize(subdevices: []const SubDevice) u32 {
    return processImageInputsSize(subdevices) + processImageOutputsSize(subdevices);
}

pub fn processImageInputsSize(subdevices: []const SubDevice) u32 {
    if (subdevices.len == 0) return 0;

    // each subdevices will be given a byte aligned area for inputs
    // and a byte aligned area for outputs.
    var bytes_used: u32 = 0;
    for (subdevices) |subdevice| {
        bytes_used += (subdevice.config.inputs_bit_length + 7) / 8;
    }
    return bytes_used;
}
pub fn processImageOutputsSize(subdevices: []const SubDevice) u32 {
    if (subdevices.len == 0) return 0;

    // each subdevices will be given a byte aligned area for inputs
    // and a byte aligned area for outputs.
    var bytes_used: u32 = 0;
    for (subdevices) |subdevice| {
        bytes_used += (subdevice.config.outputs_bit_length + 7) / 8;
    }
    return bytes_used;
}

pub fn processImageOutputsLogicalStartAddr(subdevices: []const SubDevice) u32 {
    return 0 + processImageInputsSize(subdevices);
}

test {
    std.testing.refAllDecls(@This());
}
