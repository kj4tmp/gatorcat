//! Process Data Interface
//!
//! The process data image is the logical memory address space. Subdevices can read from and write to
//! the address space. The FMMUs in each subdevice govern the translation of the logical memory
//! address space to the physical memory address space and vice-versa.

const std = @import("std");
const assert = std.debug.assert;

const SubDevice = @import("SubDevice.zig");
const ENI = @import("ENI.zig");

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

pub fn partitionProcessImage(image: []u8, subdevices: []SubDevice) !void {
    if (subdevices.len == 0) return;

    // make sure everything fits first.
    // each subdevices will be given a byte aligned area for inputs
    // and a byte aligned area for outputs.
    var bytes_used: u32 = 0;
    for (subdevices) |subdevice| {
        bytes_used += (subdevice.config.inputs_bit_length + 7) / 8;
        bytes_used += (subdevice.config.outputs_bit_length + 7) / 8;
    }
    if (image.len < bytes_used) return error.ProcessImageTooSmall;

    // most implementations tend to put inputs in the first half
    // of the image and outputs in the last half

    // assign regions for inputs
    // subdevices without inputs will receive empty slice
    var last_byte_used: u32 = 0;
    for (subdevices) |*subdevice| {
        const inputs_byte_size: u32 = (subdevice.config.inputs_bit_length + 7) / 8;
        const pi = SubDevice.RuntimeInfo.ProcessImage{
            .inputs = image[last_byte_used .. last_byte_used + inputs_byte_size],
            .inputs_area = .{ .start_addr = last_byte_used, .bit_length = subdevice.config.inputs_bit_length },
            // to be assigned in the next for loop
            .outputs = undefined,
            .outputs_area = undefined,
        };
        subdevice.runtime_info.pi = pi;
        last_byte_used += inputs_byte_size;
    }
    // assign regions for outputs
    // subdevices without outputs will receive empty slice
    for (subdevices) |*subdevice| {
        const outputs_byte_size: u32 = (subdevice.config.outputs_bit_length + 7) / 8;
        subdevice.runtime_info.pi.?.outputs = image[last_byte_used .. last_byte_used + outputs_byte_size];
        subdevice.runtime_info.pi.?.outputs_area = .{ .start_addr = last_byte_used, .bit_length = subdevice.config.outputs_bit_length };
        last_byte_used += outputs_byte_size;
    }

    // check for overlaps
    assert(subdevices.len > 0);
    // TODO: check slices too
    for (1..subdevices.len) |i| {
        const this_start = subdevices[i].runtime_info.pi.?.inputs_area.start_addr;
        const prev_start = subdevices[i - 1].runtime_info.pi.?.inputs_area.start_addr;
        const prev_len = subdevices[i - 1].runtime_info.pi.?.inputs.len;
        // having the same start addr is allowed if len == 0;
        assert(prev_start + prev_len <= this_start);
    }
}

pub fn processImageSizeFromENI(eni: ENI) u32 {
    if (eni.subdevices.len == 0) return 0;

    // each subdevices will be given a byte aligned area for inputs
    // and a byte aligned area for outputs.
    var bytes_used: u32 = 0;
    for (eni.subdevices) |subdevice_config| {
        bytes_used += (subdevice_config.inputs_bit_length + 7) / 8;
        bytes_used += (subdevice_config.outputs_bit_length + 7) / 8;
    }
    return bytes_used;
}

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
