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
    std.debug.print("PROCESS IMAGE SIZE: {}\n", .{eni.processImageSize()});
    const used_subdevices = try gcat.initSubdevicesFromENI(eni, &subdevices, &process_image);
    assert(used_subdevices.len == subdevices.len);
    var frames: [gcat.MainDevice.frameCount(@intCast(process_image.len))]gcat.telegram.EtherCATFrame = @splat(gcat.telegram.EtherCATFrame.empty);

    var main_device = try gcat.MainDevice.init(
        &port,
        .{ .recv_timeout_us = 4000, .eeprom_timeout_us = 10_000 },
        used_subdevices,
        &process_image,
        &frames,
    );

    try main_device.busINIT(5_000_000);
    try main_device.busPREOP(10_000_000);
    try main_device.busSAFEOP(10_000_000);
    try main_device.busOP(10_000_000);

    std.debug.print("EL2008 PROCESS IMAGE: {}\n", .{subdevices[3].runtime_info.pi});
    std.debug.print("EL7041 PROCESS IMAGE: {}\n", .{subdevices[4].runtime_info.pi});

    var print_timer = try std.time.Timer.start();
    var blink_timer = try std.time.Timer.start();
    var kill_timer = try std.time.Timer.start();
    var wkc_error_timer = try std.time.Timer.start();
    var cycle_count: u32 = 0;

    const ek1100 = &subdevices[0];
    const el3314 = &subdevices[1];
    const el2008 = &subdevices[4];
    const el7041 = &subdevices[3];

    var temps = el3314.packFromInputProcessData(EL3314ProcessData);
    var motor_control = EL7041Outputs.zero;
    var motor_status = std.mem.zeroes(EL7041Inputs);

    while (true) {

        // input and output mapping
        temps = el3314.packFromInputProcessData(EL3314ProcessData);
        motor_status = el7041.packFromInputProcessData(EL7041Inputs);
        el7041.packToOutputProcessData(motor_control);

        // exchange process data
        const diag = main_device.sendRecvCyclicFramesDiag() catch |err| switch (err) {
            error.RecvTimeout => {
                std.log.warn("recv timeout", .{});
                continue;
            },
            error.LinkError,
            error.CurruptedFrame,
            error.NoTransactionAvailable,
            => |err2| return err2,
        };
        if (diag.brd_status_wkc != eni.subdevices.len) return error.TopologyChanged;
        if (diag.brd_status.state != .OP) {
            std.log.err("Not all subdevices in OP! brd status {}", .{diag.brd_status});
            return error.NotAllSubdevicesInOP;
        }
        if (diag.process_data_wkc != main_device.expectedProcessDataWkc() and wkc_error_timer.read() > 1 * std.time.ns_per_s) {
            wkc_error_timer.reset();
            std.log.err("process data wkc wrong: {}, expected: {}", .{ diag.process_data_wkc, main_device.expectedProcessDataWkc() });
        }
        if (diag.process_data_wkc == main_device.expectedProcessDataWkc()) std.debug.print("SUCCESS!!!!!!!!!!!!!!\n", .{});
        cycle_count += 1;

        // do application
        if (print_timer.read() > std.time.ns_per_s * 1) {
            print_timer.reset();
            std.log.warn("frames/s: {}", .{cycle_count});
            std.log.warn("temps: {}", .{temps});
            std.log.warn("motor_status: {}", .{motor_status});
            std.debug.print("EL2008 PROCESS IMAGE: {}\n", .{subdevices[3].runtime_info.pi});
            std.debug.print("EL7041 PROCESS IMAGE: {}\n", .{subdevices[4].runtime_info.pi});
            cycle_count = 0;
            motor_control.control_reset = !motor_control.control_reset;
        }
        if (blink_timer.read() > std.time.ns_per_s * 0.1) {
            blink_timer.reset();
            // make the lights flash on the EL2008
            el2008.runtime_info.pi.outputs[0] *%= 2;
            if (el2008.runtime_info.pi.outputs[0] == 0) {
                el2008.runtime_info.pi.outputs[0] = 1;
            }
        }
        if (kill_timer.read() > std.time.ns_per_s * 100) {
            kill_timer.reset();
            try ek1100.setALState(&port, .SAFEOP, 10000, 10000);
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

    const zero = EL7041Outputs{
        .control_enable = false,
        .control_enable_latch_c = false,
        .control_enable_latch_extern_neg_edge = false,
        .control_enable_latch_extern_pos_edge = false,
        .control_reduce_torque = false,
        .control_reset = false,
        .control_set_counter = false,
        .set_counter_value = 0,
        .velocity = 0,
    };
};

const EL7041Inputs = packed struct(u64) {
    encoder_flags: u16,
    encoder_value: u16,
    encoder_latch_value: u16,
    status: STMStatus,

    const STMStatus = packed struct(u16) {
        ready_to_enable: bool,
        ready: bool,
        warning: bool,
        @"error": bool,
        move_pos: bool,
        move_neg: bool,
        torque_reduced: bool,
        reserved: u4 = 0,
        dig_in_1: bool,
        dig_in_2: bool,
        sync_error: bool,
        reserved2: u1 = 0,
        tx_pdo_toggle: bool,
    };
};
