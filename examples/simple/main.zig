const std = @import("std");

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
    var subdevices: [eni.subdevices.len]gcat.SubDevice = gcat.subdevicesFromENI(eni);
    var process_image = std.mem.zeroes([gcat.pdi.processImageSize(&gcat.subdevicesFromENI(eni))]u8);
    var frames: [256]gcat.telegram.EtherCATFrame = undefined;

    var main_device = try gcat.MainDevice.init(
        &port,
        .{},
        &subdevices,
        &process_image,
        &frames,
    );

    try main_device.busINIT(5_000_000);
    try main_device.busPREOP(10_000_000);
    try main_device.busSAFEOP(10_000_000);
    try main_device.busOP(10_000_000);

    var timer = try std.time.Timer.start();
    var timer2 = try std.time.Timer.start();
    var timer3 = try std.time.Timer.start();
    var timer4 = try std.time.Timer.start();
    var timer5 = try std.time.Timer.start();
    var wkc_error_timer = try std.time.Timer.start();
    var frame_count: u32 = 0;

    while (true) {
        timer4.reset();
        const wkc = main_device.sendRecvCyclicFrames() catch |err| switch (err) {
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
            error.Overflow,
            error.NoSpaceLeft,
            error.FrameSerializationFailure,
            error.EndOfStream,
            error.NotAllSubdevicesInOP,
            error.ProcessImageTooLarge,
            error.NotEnoughFrames,
            error.NoTransactionAvailable,
            error.TopologyChanged,
            => |err2| return err2,
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

            // write to el7041
            var fb3 = std.io.fixedBufferStream(subdevices[4].runtime_info.pi.?.outputs);
            const writer3 = fb3.writer();
            try gcat.wire.eCatFromPackToWriter(EL7041Outputs.enabled, writer3);
        }

        if (timer2.read() > std.time.ns_per_s * 0.1) {
            timer2.reset();
            // make the lights flash on the EL2008
            subdevices[3].runtime_info.pi.?.outputs[0] *%= 2;
            if (subdevices[3].runtime_info.pi.?.outputs[0] == 0) {
                subdevices[3].runtime_info.pi.?.outputs[0] = 1;
            }
        }

        timer3.reset();

        if (timer5.read() > std.time.ns_per_s * 5) {
            timer5.reset();
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
