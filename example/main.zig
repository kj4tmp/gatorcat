const std = @import("std");

const gcat = @import("gatorcat");

pub const std_options = .{
    .log_level = .info,
};

const beckhoff_EK1100 = gcat.sii.SubDeviceIdentity{ .vendor_id = 0x2, .product_code = 0x44c2c52, .revision_number = 0x110000 };
const beckhoff_EL3314 = gcat.sii.SubDeviceIdentity{ .vendor_id = 0x2, .product_code = 0xcf23052, .revision_number = 0x120000 };
const beckhoff_EL3048 = gcat.sii.SubDeviceIdentity{ .vendor_id = 0x2, .product_code = 0xbe83052, .revision_number = 0x130000 };
const beckhoff_EL7041_1000 = gcat.sii.SubDeviceIdentity{ .vendor_id = 0x2, .product_code = 0x1b813052, .revision_number = 0x1503e8 };
const beckhoff_EL2008 = gcat.sii.SubDeviceIdentity{ .vendor_id = 0x2, .product_code = 0x7d83052, .revision_number = 0x100000 };

var subdevices: [255]gcat.SubDevice = undefined;
var process_image = std.mem.zeroes([255]u8);

const eni = gcat.ENI{
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
    var port = try gcat.nic.Port.init("enx00e04c68191a");
    defer port.deinit();

    var main_device = try gcat.MainDevice.init(
        &port,
        .{},
        &eni,
        &subdevices,
        &process_image,
    );

    try main_device.busINIT();
    try main_device.busPREOP();
    try main_device.busSAFEOP();
    try main_device.busOP();

    var timer = try std.time.Timer.start();
    var timer2 = try std.time.Timer.start();
    var timer3 = try std.time.Timer.start();
    var timer4 = try std.time.Timer.start();
    var frame_count: u32 = 0;

    while (true) {
        timer4.reset();
        const wkc = main_device.sendCyclicFrame() catch |err| switch (err) {
            error.RecvTimeout => {
                std.log.warn("recv timeout", .{});
                continue;
            },
            error.LinkError, error.TransactionContention, error.CurruptedFrame => |err2| return err2,
        };
        const recv_us = timer4.read() / std.time.ns_per_us;
        frame_count += 1;

        // std.time.sleep(std.time.ns_per_ms * 1);

        if (timer.read() > std.time.ns_per_s * 1) {
            timer.reset();
            std.log.warn("wkc: {}, recv_us: {}, timer3: {}, frames/s: {}", .{ wkc, recv_us, timer3.read() / std.time.ns_per_us, frame_count });
            var fbs2 = std.io.fixedBufferStream(subdevices[1].runtime_info.pi.?.inputs);
            const reader2 = fbs2.reader();
            std.log.warn("el3314: {}", .{(try gcat.wire.packFromECatReader(EL3314ProcessData, reader2)).ch1});
            frame_count = 0;
        }

        if (timer2.read() > std.time.ns_per_s * 0.1) {
            timer2.reset();
            // make the lights flash on the EL2008
            subdevices[4].runtime_info.pi.?.outputs[0] *%= 2;
            if (subdevices[4].runtime_info.pi.?.outputs[0] == 0) {
                subdevices[4].runtime_info.pi.?.outputs[0] = 1;
            }
        }

        timer3.reset();
    }
}

const EL3314Channel = packed struct(u32) {
    underrange: bool,
    overrange: bool,
    limit1: u2,
    limit2: u2,
    err: bool,
    _reserved: u7,
    txpdo_state: bool,
    txpdo_toggle: bool,
    value: u16,
};

const EL3314ProcessData = packed struct {
    ch1: EL3314Channel,
    ch2: EL3314Channel,
    ch3: EL3314Channel,
    ch4: EL3314Channel,
};
