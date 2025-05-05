const std = @import("std");
const assert = std.debug.assert;
const builtin = @import("builtin");

const gcat = @import("gatorcat");

const eni = @import("network_config.zig").eni;

pub const std_options: std.Options = .{
    .log_level = .info,
};

pub fn main() !void {
    var raw_socket = try gcat.nic.RawSocket.init("enx00e04c68191a");
    defer raw_socket.deinit();
    var port = gcat.Port.init(raw_socket.linkLayer(), .{});
    defer port.deinit();
    try port.ping(10000);

    const estimated_stack_usage = 300000;
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

    var print_timer = try std.time.Timer.start();
    var kill_timer = try std.time.Timer.start();
    var wkc_error_timer = try std.time.Timer.start();
    var cycle_count: u32 = 0;

    const ek1100 = &md.subdevices[0];
    const el7031 = &md.subdevices[1];

    var motor_control = EL7031Outputs.zero;
    var motor_status = std.mem.zeroes(EL7031Inputs);

    const first_cycle_time = std.time.Instant.now() catch @panic("Timer unsupported");
    try md.sendCyclicFrames();
    gcat.sleepUntilNextCycle(first_cycle_time, 2000);

    while (true) {
        // recv frames
        const recv_result = md.recvCyclicFrames();
        if (recv_result) |diag| {
            if (diag.brd_status_wkc != eni.subdevices.len) return error.TopologyChanged;
            if (diag.brd_status.state != .OP) {
                std.log.err("Not all subdevices in OP! brd status {}", .{diag.brd_status});
                return error.NotAllSubdevicesInOP;
            }
            if (diag.process_data_wkc != md.expectedProcessDataWkc() and wkc_error_timer.read() > 1 * std.time.ns_per_s) {
                wkc_error_timer.reset();
                std.log.err("process data wkc wrong: {}, expected: {}", .{ diag.process_data_wkc, md.expectedProcessDataWkc() });
            }
        } else |recv_error| switch (recv_error) {
            error.RecvTimeout => {
                std.log.warn("recv timeout", .{});
            },
            error.LinkError,
            => |err2| return err2,
        }

        // input mapping
        motor_status = el7031.packFromInputProcessData(EL7031Inputs);

        // do application
        if (print_timer.read() > std.time.ns_per_s * 1) {
            print_timer.reset();
            std.debug.print("----------------------------------\n", .{});
            std.log.warn("frames/s: {}", .{cycle_count});
            std.log.warn("motor_status: {}", .{motor_status});
            std.log.warn("motor_control: {}", .{motor_control});
            std.debug.print("EL7031 PROCESS IMAGE: {}\n", .{el7031.runtime_info.pi});
            std.debug.print("Full PROCESS IMAGE: {any}\n", .{md.process_image});
            std.debug.print("----------------------------------\n", .{});
            cycle_count = 0;
            if (motor_status.status.ready_to_enable) { // and !motor_status.status.@"error") {
                motor_control.control_enable = true;
                motor_control.control_reset = false;
            } else {
                motor_control.control_enable = false;
            }
        }
        if (kill_timer.read() > std.time.ns_per_s * 10) {
            kill_timer.reset();
            try ek1100.setALState(&port, .SAFEOP, 10000, 10000);
        }
        // output mapping
        el7031.packToOutputProcessData(motor_control);

        // send frames
        try md.sendCyclicFrames();

        // sleep until next cycle
        gcat.sleepUntilNextCycle(first_cycle_time, 2000);

        cycle_count += 1;
    }
}

const EL7031Inputs = packed struct(u128) {
    encoder_flags: u16,
    encoder_value: u16,
    encoder_latch_value: u16,
    status: STMStatus,
    ai_1: u32,
    ai_2: u32,

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

const EL7031Outputs = packed struct(u64) {
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

    const zero = EL7031Outputs{
        .control_enable = false,
        .control_enable_latch_c = false,
        .control_enable_latch_extern_neg_edge = false,
        .control_enable_latch_extern_pos_edge = false,
        .control_reduce_torque = false,
        .control_reset = false,
        .control_set_counter = false,
        .set_counter_value = 0,
        .velocity = 10,
    };
};
