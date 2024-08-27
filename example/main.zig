const std = @import("std");

const nic = @import("ecm").nic;
const MainDevice = @import("ecm").MainDevice;
const BusConfiguration = @import("ecm").BusConfiguration;
const Subdevice = @import("ecm").Subdevice;
const SubdeviceRuntimeInfo = @import("ecm").SubdeviceRuntimeInfo;

pub const std_options = .{
    .log_level = .info,
};

const beckhoff_EK1100 = Subdevice{ .vendor_id = 0x2, .product_code = 0x44c2c52, .revision_number = 0x110000 };
const beckhoff_EL3314 = Subdevice{ .vendor_id = 0x2, .product_code = 0xcf23052, .revision_number = 0x120000 };
const beckhoff_EL3048 = Subdevice{ .vendor_id = 0x2, .product_code = 0xbe83052, .revision_number = 0x130000 };

const bus_config = BusConfiguration{
    .subdevices = &.{
        beckhoff_EK1100,
        beckhoff_EL3314,
        beckhoff_EL3048,
    },
};

var bus = [3]SubdeviceRuntimeInfo{ .{}, .{}, .{} };

pub fn main() !void {
    var port = try nic.Port.init("enx00e04c68191a");
    defer port.deinit();

    var main_device = MainDevice.init(
        &port,
        .{ .timeout_recv_us = 2000 },
        bus_config,
        &bus,
    );

    try main_device.bus_init();
}
