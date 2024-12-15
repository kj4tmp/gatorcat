const std = @import("std");
const assert = std.debug.assert;

pub const ENI = @import("ENI.zig");
pub const esc = @import("esc.zig");
pub const mailbox = @import("mailbox.zig");
pub const MainDevice = @import("MainDevice.zig");
pub const nic = @import("nic.zig");
pub const pdi = @import("pdi.zig");
pub const Port = @import("Port.zig");
pub const Scanner = @import("Scanner.zig");
pub const sii = @import("sii.zig");
pub const SubDevice = @import("SubDevice.zig");
pub const telegram = @import("telegram.zig");
pub const wire = @import("wire.zig");

const gcat = @This();

/// initialize a slice of undefined subdevices using information from the ENI.
/// Returns slice of subdevices that has been initialized.
pub fn initSubdevicesFromENI(eni: ENI, subdevices: []SubDevice, process_image: []u8) ![]SubDevice {
    assert(eni.subdevices.len <= max_subdevices);
    if (eni.subdevices.len < subdevices.len) {
        return error.NotEnoughSubdevices;
    }
    if (eni.processImageSize() < process_image.len) {
        return error.ProcessImageTooSmall;
    }

    const process_image_stats = eni.processImageStats();
    var subdevices_used: u16 = 0;
    var last_input_byte_idx: u32 = 0;
    var last_output_byte_idx: u32 = process_image_stats.input_bytes;
    for (subdevices, 0..) |*subdevice, i| {
        defer subdevices_used += 1;

        const subdevice_config = eni.subdevices[i];
        // Most implementations put inputs in the first half
        // of the image and outputs in the last half
        // we will do the smae.
        // subdevices without inputs or outputs will receive empty slice
        const inputs_byte_size: u32 = (subdevice_config.inputs_bit_length + 7) / 8;
        const outputs_byte_size: u32 = (subdevice_config.outputs_bit_length + 7) / 8;
        const pi = SubDevice.ProcessImage{
            .inputs = process_image[last_input_byte_idx .. last_input_byte_idx + inputs_byte_size],
            .inputs_area = .{ .start_addr = last_input_byte_idx, .bit_length = subdevice_config.inputs_bit_length },
            .outputs = process_image[last_output_byte_idx .. last_output_byte_idx + outputs_byte_size],
            .outputs_area = .{ .start_addr = last_output_byte_idx, .bit_length = subdevice_config.outputs_bit_length },
        };
        last_input_byte_idx += inputs_byte_size;
        last_output_byte_idx += outputs_byte_size;
        subdevice.* = SubDevice.init(subdevice_config, @intCast(i), pi);
    }
    assert(last_input_byte_idx == process_image_stats.input_bytes);
    assert(last_output_byte_idx == eni.processImageSize());

    // check for overlaps
    assert(subdevices.len > 0);
    // TODO: check slices too
    for (1..subdevices.len) |i| {
        const this_start = subdevices[i].runtime_info.pi.inputs_area.start_addr;
        assert(this_start <= process_image.len);
        const prev_start = subdevices[i - 1].runtime_info.pi.inputs_area.start_addr;
        assert(prev_start <= process_image.len);
        const prev_len = subdevices[i - 1].runtime_info.pi.inputs.len;
        // having the same start addr is allowed if len == 0;
        assert(prev_start + prev_len <= this_start);
    }
    for (1..subdevices.len) |i| {
        const this_start = subdevices[i].runtime_info.pi.outputs_area.start_addr;
        assert(this_start <= process_image.len);
        const prev_start = subdevices[i - 1].runtime_info.pi.outputs_area.start_addr;
        assert(prev_start <= process_image.len);
        const prev_len = subdevices[i - 1].runtime_info.pi.outputs.len;
        // having the same start addr is allowed if len == 0;
        assert(prev_start + prev_len <= this_start);
    }

    return subdevices[0..subdevices_used];
}

pub const max_subdevices = 65535;

test {
    std.testing.refAllDecls(@This());
}
