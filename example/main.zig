const std = @import("std");

const nic = @import("ecm").nic;
const MainDevice = @import("ecm").MainDevice;
const BusConfiguration = @import("ecm").BusConfiguration;
const SubDevice = @import("ecm").SubDevice;
const SubDeviceRuntimeInfo = @import("ecm").SubDeviceRuntimeInfo;
const coe = @import("ecm").coe;

pub const std_options = .{
    .log_level = .info,
};

const beckhoff_EK1100 = SubDevice{ .vendor_id = 0x2, .product_code = 0x44c2c52, .revision_number = 0x110000 };
const beckhoff_EL3314 = SubDevice{ .vendor_id = 0x2, .product_code = 0xcf23052, .revision_number = 0x120000 };
const beckhoff_EL3048 = SubDevice{ .vendor_id = 0x2, .product_code = 0xbe83052, .revision_number = 0x130000 };

const bus_config = BusConfiguration{
    .subdevices = &.{
        beckhoff_EK1100,
        beckhoff_EL3314,
        beckhoff_EL3048,
    },
};

var bus = [3]SubDeviceRuntimeInfo{ .{}, .{}, .{} };

pub fn main() !void {
    var port = try nic.Port.init("enx00e04c68191a");
    defer port.deinit();

    var main_device = MainDevice.init(
        &port,
        .{},
        bus_config,
        &bus,
    );

    try main_device.busINIT();
    try main_device.busPREOP();
    try main_device.busSAFEOP();
}
