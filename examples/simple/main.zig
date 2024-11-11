const std = @import("std");
const assert = std.debug.assert;

const gcat = @import("gatorcat");

const eni = @import("network_config.zig").eni;

pub const std_options: std.Options = .{
    .log_level = .info,
};

pub fn main() !void {
    var raw_socket = try gcat.nic.RawSocket.init("enx00e04c68191a");
    defer raw_socket.deinit();
    var port = gcat.Port.init(raw_socket.networkAdapter(), .{});
    try port.ping(10000);

    // Since the ENI is known at comptime for this example,
    // we can construct exact stack usage here.
    var subdevices: [eni.subdevices.len]gcat.SubDevice = undefined;
    var process_image = std.mem.zeroes([eni.processImageSize()]u8);
    const used_subdevices = try gcat.initSubdevicesFromENI(eni, &subdevices, &process_image);
    assert(used_subdevices.len == subdevices.len);

    var frames: [256]gcat.telegram.EtherCATFrame = .{gcat.telegram.EtherCATFrame.empty} ** 256;

    var main_device = try gcat.MainDevice.init(
        &port,
        .{ .recv_timeout_us = 3000, .eeprom_timeout_us = 10_000 },
        used_subdevices,
        &process_image,
        &frames,
    );

    try main_device.busINIT(5_000_000);
    try main_device.busPREOP(10_000_000);
    try main_device.busSAFEOP(10_000_000);
    try main_device.busOP(10_000_000);

    var print_timer = try std.time.Timer.start();
    var blink_timer = try std.time.Timer.start();
    var kill_timer = try std.time.Timer.start();
    var wkc_error_timer = try std.time.Timer.start();
    var cycle_count: u32 = 0;

    const el3314 = &subdevices[1];
    const el7041 = &subdevices[4];

    var temps = el3314.packFromInputProcessData(EL3314ProcessData);
    const motor_control = EL7041Outputs.enabled;

    while (true) {

        // input and output mapping
        temps = el3314.packFromInputProcessData(EL3314ProcessData);
        el7041.packToOutputProcessData(motor_control);

        // exchange process data
        main_device.sendRecvCyclicFrames() catch |err| switch (err) {
            error.RecvTimeout => {
                std.log.warn("recv timeout", .{});
                continue;
            },
            error.Wkc => {
                if (wkc_error_timer.read() > 1 * std.time.ns_per_s) {
                    wkc_error_timer.reset();
                    std.log.warn("wkc error", .{});
                }
            },
            // error.Wkc,
            error.LinkError,
            error.CurruptedFrame,
            error.NotAllSubdevicesInOP,
            error.ProcessImageTooLarge,
            error.NotEnoughFrames,
            error.NoTransactionAvailable,
            error.TopologyChanged,
            => |err2| return err2,
        };
        cycle_count += 1;

        // do application
        if (print_timer.read() > std.time.ns_per_s * 1) {
            print_timer.reset();
            std.log.warn("frames/s: {}", .{cycle_count});
            std.log.warn("temps: {}", .{temps});
            cycle_count = 0;
        }
        if (blink_timer.read() > std.time.ns_per_s * 0.1) {
            blink_timer.reset();
            // make the lights flash on the EL2008
            subdevices[3].runtime_info.pi.outputs[0] *%= 2;
            if (subdevices[3].runtime_info.pi.outputs[0] == 0) {
                subdevices[3].runtime_info.pi.outputs[0] = 1;
            }
        }
        if (kill_timer.read() > std.time.ns_per_s * 5) {
            kill_timer.reset();
            try subdevices[0].setALState(&port, .SAFEOP, 10000, 10000);
        }
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

const EL7041Outputs = packed struct(u64) {
    control_enable_latch_c: bool,
    control_enable_latch_extern_pos_edge: bool,
    control_set_counter: bool,
    control_enable_latch_extern_neg_edge: bool,
    reserved: u12 = 0,
    set_counter_value: u16,
    control_enable: bool,
    control_reset: bool,
    control_reduce_torque: bool,
    reserved2: u13 = 0,
    velocity: i16,

    const enabled = EL7041Outputs{
        .control_enable = true,
        .control_enable_latch_c = false,
        .control_enable_latch_extern_neg_edge = false,
        .control_enable_latch_extern_pos_edge = false,
        .control_reduce_torque = true,
        .control_reset = false,
        .control_set_counter = false,
        .set_counter_value = 0,
        .velocity = 0,
    };
};
