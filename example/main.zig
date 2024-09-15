const std = @import("std");

const ecm = @import("ecm");

pub const std_options = .{
    .log_level = .info,
};

const beckhoff_EK1100 = ecm.SubDevice.PriorInfo{ .vendor_id = 0x2, .product_code = 0x44c2c52, .revision_number = 0x110000 };
const beckhoff_EL3314 = ecm.SubDevice.PriorInfo{ .vendor_id = 0x2, .product_code = 0xcf23052, .revision_number = 0x120000 };
const beckhoff_EL3048 = ecm.SubDevice.PriorInfo{ .vendor_id = 0x2, .product_code = 0xbe83052, .revision_number = 0x130000 };

var subdevices: [3]ecm.SubDevice = .{
    ecm.SubDevice.init(beckhoff_EK1100),
    ecm.SubDevice.init(beckhoff_EL3314),
    ecm.SubDevice.init(beckhoff_EL3048),
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
    //subdevices[1].runtime_info.station_address = 0x1001;
    // _ = ecm.SubDevice.setALState(
    //     &subdevices[1],
    //     &port,
    //     .PREOP,
    //     30000,
    //     3000,
    // ) catch |err| switch (err) {
    //     error.StateChangeRefused => .{},
    //     error.LinkError => unreachable,
    //     error.TransactionContention => unreachable,
    //     error.RecvTimeout => return error.RecvTimeout,
    //     error.CurruptedFrame => return error.CurruptedFrame,
    //     error.InvalidRuntimeInfo => unreachable,
    //     error.StateChangeTimeout => unreachable,
    //     error.Wkc => return error.Wkc,
    // };

    std.debug.print("{any}", .{try ecm.mailbox.readMailboxIn(&port, 0x1001, 3000)});
}
