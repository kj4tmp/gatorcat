const std = @import("std");

const ecm = @import("ecm");

pub const std_options = .{
    .log_level = .info,
};

const beckhoff_EK1100 = ecm.SubDevice.PriorInfo{ .vendor_id = 0x2, .product_code = 0x44c2c52, .revision_number = 0x110000 };
const beckhoff_EL3314 = ecm.SubDevice.PriorInfo{ .vendor_id = 0x2, .product_code = 0xcf23052, .revision_number = 0x120000 };
const beckhoff_EL3048 = ecm.SubDevice.PriorInfo{ .vendor_id = 0x2, .product_code = 0xbe83052, .revision_number = 0x130000 };
const beckhoff_EL7041_1000 = ecm.SubDevice.PriorInfo{ .vendor_id = 0x2, .product_code = 0x1b813052, .revision_number = 0x1503e8 };

var subdevices: [4]ecm.SubDevice = .{
    ecm.SubDevice.init(beckhoff_EK1100),
    ecm.SubDevice.init(beckhoff_EL3314),
    ecm.SubDevice.init(beckhoff_EL3048),
    ecm.SubDevice.init(beckhoff_EL7041_1000),
};

const bus = ecm.MainDevice.BusConfiguration{
    .subdevices = &subdevices,
};

pub fn main() !void {
    var port = try ecm.nic.Port.init("enx00e04c68191a");
    defer port.deinit();

    var main_device = ecm.MainDevice.init(
        &port,
        .{},
        bus,
    );

    try main_device.busINIT();
    try main_device.busPREOP();
    //try main_device.busSAFEOP();

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
}
