const std = @import("std");
const assert = std.debug.assert;
const builtin = @import("builtin");

const gcat = @import("gatorcat");

const eni = @import("network_config.zig").eni;

pub const std_options: std.Options = .{
    .log_level = .info,
};

pub fn main() !void {
    var raw_socket = switch (builtin.target.os.tag) {
        .linux => try gcat.nic.RawSocket.init("enx00e04c68191a"),
        .windows => try gcat.nic.WindowsRawSocket.init("\\Device\\NPF_{538CF305-6539-480E-ACD9-BEE598E7AE8F}"),
        else => @compileError("unsupported target os"),
    };
    defer raw_socket.deinit();
    var port = gcat.Port.init(raw_socket.linkLayer(), .{});
    try port.ping(10000);

    const estimated_stack_usage = comptime gcat.MainDevice.estimateAllocSize(eni) + 8;
    var stack_memory: [estimated_stack_usage]u8 = undefined;
    var stack_fba = std.heap.FixedBufferAllocator.init(&stack_memory);

    var md = try gcat.MainDevice.init(
        stack_fba.allocator(),
        &port,
        .{ .recv_timeout_us = 20000, .eeprom_timeout_us = 10_000 },
        eni,
    );
    defer md.deinit(stack_fba.allocator());

    try md.busInit(5_000_000);
    try md.busPreop(10_000_000);
    try md.busSafeop(10_000_000);
    try md.busOp(10_000_000);

    std.debug.print("EL2008 PROCESS IMAGE: {}\n", .{md.subdevices[3].runtime_info.pi});
    std.debug.print("EL7041 PROCESS IMAGE: {}\n", .{md.subdevices[4].runtime_info.pi});

    var print_timer = try std.time.Timer.start();
    var blink_timer = try std.time.Timer.start();
    var kill_timer = try std.time.Timer.start();
    var wkc_error_timer = try std.time.Timer.start();
    var cycle_count: u32 = 0;

    const ek1100 = &md.subdevices[0];
    const el3314 = &md.subdevices[1];
    const el2008 = &md.subdevices[3];
    const el7041 = &md.subdevices[4];

    var temps = el3314.packFromInputProcessData(EL3314ProcessData);
    var motor_control = EL7041Outputs.zero;
    var motor_status = std.mem.zeroes(EL7041Inputs);

    while (true) {

        // input and output mapping
        temps = el3314.packFromInputProcessData(EL3314ProcessData);
        motor_status = el7041.packFromInputProcessData(EL7041Inputs);
        el7041.packToOutputProcessData(motor_control);

        // exchange process data
        const diag = md.sendRecvCyclicFramesDiag() catch |err| switch (err) {
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
        if (diag.process_data_wkc != md.expectedProcessDataWkc() and wkc_error_timer.read() > 1 * std.time.ns_per_s) {
            wkc_error_timer.reset();
            std.log.err("process data wkc wrong: {}, expected: {}", .{ diag.process_data_wkc, md.expectedProcessDataWkc() });
        }
        if (diag.process_data_wkc == md.expectedProcessDataWkc()) std.debug.print("SUCCESS!!!!!!!!!!!!!!\n", .{});
        cycle_count += 1;

        // do application
        if (print_timer.read() > std.time.ns_per_s * 1) {
            print_timer.reset();
            std.log.warn("frames/s: {}", .{cycle_count});
            std.log.warn("temps: {}", .{temps});
            std.log.warn("motor_status: {}", .{motor_status});
            std.debug.print("EL2008 PROCESS IMAGE: {}\n", .{md.subdevices[3].runtime_info.pi});
            std.debug.print("EL7041 PROCESS IMAGE: {}\n", .{md.subdevices[4].runtime_info.pi});
            cycle_count = 0;
            if (motor_status.status.ready_to_enable) {
                motor_control.control_enable = true;
            } else {
                motor_control.control_reset = !motor_control.control_reset;
                motor_control.control_enable = false;
            }
        }
        if (blink_timer.read() > std.time.ns_per_s * 0.1) {
            blink_timer.reset();
            // make the lights flash on the EL2008
            el2008.runtime_info.pi.outputs[0] *%= 2;
            if (el2008.runtime_info.pi.outputs[0] == 0) {
                el2008.runtime_info.pi.outputs[0] = 1;
            }
        }
        if (kill_timer.read() > std.time.ns_per_s * 10) {
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
