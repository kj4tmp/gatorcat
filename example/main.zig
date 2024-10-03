const std = @import("std");

const ecm = @import("ecm");

pub const std_options = .{
    .log_level = .info,
};

const beckhoff_EK1100 = ecm.sii.SubDeviceIdentity{ .vendor_id = 0x2, .product_code = 0x44c2c52, .revision_number = 0x110000 };
const beckhoff_EL3314 = ecm.sii.SubDeviceIdentity{ .vendor_id = 0x2, .product_code = 0xcf23052, .revision_number = 0x120000 };
const beckhoff_EL3048 = ecm.sii.SubDeviceIdentity{ .vendor_id = 0x2, .product_code = 0xbe83052, .revision_number = 0x130000 };
const beckhoff_EL7041_1000 = ecm.sii.SubDeviceIdentity{ .vendor_id = 0x2, .product_code = 0x1b813052, .revision_number = 0x1503e8 };
const beckhoff_EL2008 = ecm.sii.SubDeviceIdentity{ .vendor_id = 0x2, .product_code = 0x7d83052, .revision_number = 0x100000 };

var subdevices: [255]ecm.SubDevice = undefined;
var process_image = std.mem.zeroes([255]u8);

const eni = ecm.ENI{
    .subdevices = &.{
        .{
            .identity = beckhoff_EK1100,
            .station_address = 0x1000,
            .ring_position = 0,
        },
        .{
            .identity = beckhoff_EL3314,
            .station_address = 0x1001,
            .ring_position = 1,
            .coe_startup_parameters = &.{
                .{
                    .transition = .PS,
                    .direction = .write,
                    .index = 0x8000,
                    .subindex = 0x2,
                    .complete_access = false,
                    .data = &.{2},
                    .timeout_us = 10_000,
                },
            },
            .inputs_bit_length = 128,
        },
        .{
            .identity = beckhoff_EL3048,
            .station_address = 0x1002,
            .ring_position = 2,
            .inputs_bit_length = 256,
        },
        .{
            .identity = beckhoff_EL7041_1000,
            .station_address = 0x1003,
            .ring_position = 3,
            .inputs_bit_length = 64,
            .outputs_bit_length = 64,
        },
        .{
            .identity = beckhoff_EL2008,
            .station_address = 0x1004,
            .ring_position = 4,
            .outputs_bit_length = 8,
        },
    },
};

pub fn main() !void {
    var port = try ecm.nic.Port.init("enx00e04c68191a");
    defer port.deinit();

    var main_device = ecm.MainDevice.init(
        &port,
        .{},
        &eni,
        &subdevices,
        &process_image,
    );

    try main_device.busINIT();
    try main_device.busPREOP();
    try main_device.busSAFEOP();

    // config EL3314 for high resolution mode

    try subdevices[1].sdoWrite(
        &port,
        &.{2},
        0x8000,
        0x2,
        false,
        3000,
        10_000,
    );

    var bytes = std.mem.zeroes([255]u8);
    const n_bytes = try subdevices[1].sdoRead(
        &port,
        &bytes,
        0x6000,
        0x11,
        false,
        3000,
        10_000,
    );
    std.log.warn("got {} bytes: {x}", .{ n_bytes, bytes[0..n_bytes] });
    var fbs = std.io.fixedBufferStream(&bytes);
    const reader = fbs.reader();
    std.log.warn("got {}", .{try ecm.wire.packFromECatReader(i16, reader)});

    const res = try ecm.sii.readPDOs(&port, 0x1004, .rx, 3000, 10_000) orelse return error.NoPDOs;
    for (res.slice()) |pdo| {
        if (try ecm.sii.readSIIString(&port, 0x1004, pdo.header.name_idx, 3000, 10_000)) |name| {
            std.log.warn("pdo name: {s}", .{name.slice()});
        }
        std.log.warn("pdo index: 0x{x}, full: {}", .{ pdo.header.index, pdo.header });
        for (pdo.entries.slice()) |entry| {
            if (try ecm.sii.readSIIString(&port, 0x1004, entry.name_idx, 3000, 10_000)) |name| {
                std.log.warn("    name: {s}", .{name.slice()});
            }
            std.log.warn("    index: 0x{x}, subindex: 0x{x}, data type: {}, full: {}", .{ entry.index, entry.subindex, entry.data_type, entry });
        }
    }
    std.log.warn("res size: {any}", .{@sizeOf(@TypeOf(res))});

    std.log.warn("pdo bit len: {}", .{ecm.sii.pdoBitLength(res.slice())});
    const config = ecm.mailbox.Configuration{ .mbx_in = .{ .start_addr = 0x1080, .length = 128 }, .mbx_out = .{ .start_addr = 0x1000, .length = 128 } };
    const mapping = try ecm.mailbox.coe.readPDOMapping(&port, 0x1001, 3000, 10_000, &subdevices[1].runtime_info.cnt, config, 0x1600);
    std.log.err("mapping: {any}", .{mapping.entries.slice()});

    const bitlengths = try ecm.sii.readSMPDOBitLengths(&port, 0x1003, 3000, 10000) orelse return error.NoSyncManagers;

    std.log.err("bitlengths: {any}", .{bitlengths.slice()});
}
