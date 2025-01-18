const std = @import("std");
const assert = std.debug.assert;

const ENI = @import("ENI.zig");
const esc = @import("esc.zig");
const FrameBuilder = @import("FrameBuilder.zig");
const gcat = @import("root.zig");
const nic = @import("nic.zig");
const pdi = @import("pdi.zig");
const Port = @import("Port.zig");
const sii = @import("sii.zig");
const SubDevice = @import("SubDevice.zig");
const telegram = @import("telegram.zig");
const wire = @import("wire.zig");

const MainDevice = @This();

port: *Port,
settings: Settings,
subdevices: []SubDevice,
process_image: []u8,
frames: []telegram.EtherCATFrame,
transactions: std.BoundedArray(u8, max_frames_in_flight),
first_cycle_time: ?std.time.Instant = null,

pub const Settings = struct {
    recv_timeout_us: u32 = 2000,
    eeprom_timeout_us: u32 = 10000,
    mbx_timeout_us: u32 = 50000,
};

pub fn init(
    allocator: std.mem.Allocator,
    port: *Port,
    settings: Settings,
    eni: ENI,
) !MainDevice {
    const process_image = try allocator.alloc(u8, eni.processImageSize());
    errdefer allocator.free(process_image);
    @memset(process_image, 0);

    const frames = try allocator.alloc(telegram.EtherCATFrame, frameCount(eni.processImageSize()));
    errdefer allocator.free(frames);
    assert(frameCount(eni.processImageSize()) <= frames.len);
    @memset(frames, telegram.EtherCATFrame.empty);

    const subdevices = try allocator.alloc(SubDevice, eni.subdevices.len);
    errdefer allocator.free(subdevices);
    const initialized_subdevices = gcat.initSubdevicesFromENI(eni, subdevices, process_image) catch |err| switch (err) {
        error.NotEnoughSubdevices => unreachable,
        error.ProcessImageTooSmall => unreachable,
    };
    assert(subdevices.len == initialized_subdevices.len);

    return MainDevice{
        .port = port,
        .settings = settings,
        .subdevices = initialized_subdevices,
        .process_image = process_image,
        .frames = frames,
        .transactions = .{},
    };
}

pub fn deinit(self: *MainDevice, allocator: std.mem.Allocator) void {
    allocator.free(self.process_image);
    allocator.free(self.frames);
    allocator.free(self.subdevices);
}

/// returns minimum required size of allocated memory from the ENI
pub fn estimateAllocSize(eni: ENI) usize {
    return @sizeOf(u8) * eni.processImageSize() +
        @sizeOf(telegram.EtherCATFrame) * frameCount(eni.processImageSize()) +
        @sizeOf(SubDevice) * eni.subdevices.len;
}

/// Initialize the ethercat bus.
///
/// Sets all subdevices to the INIT state.
/// Puts the bus in a known good starting configuration.
pub fn busInit(self: *MainDevice, change_timeout_us: u32) !void {

    // open all ports
    var wkc = try self.port.bwrPack(
        esc.DLControlRegisterCompact{
            .forwarding_rule = true, // destroy non-ecat frames
            .temporary_loop_control = false, // permanent settings
            .loop_control_port0 = .auto,
            .loop_control_port1 = .auto,
            .loop_control_port2 = .auto,
            .loop_control_port3 = .auto,
        },
        .{
            .autoinc_address = 0,
            .offset = @intFromEnum(esc.RegisterMap.DL_control),
        },
        self.settings.recv_timeout_us,
    );
    std.log.info("bus wipe open all ports wkc: {}", .{wkc});

    // TODO: set IRQ mask

    // reset CRC counters
    wkc = try self.port.bwrPack(

        // a write to any one of these counters will reset them all,
        // but I am too lazt to do it any differently.
        esc.RXErrorCounterRegister{
            .port0_frame_errors = 0,
            .port0_physical_errors = 0,
            .port1_frame_errors = 0,
            .port1_physical_errors = 0,
            .port2_frame_errors = 0,
            .port2_physical_errors = 0,
            .port3_frame_errors = 0,
            .port3_physical_errors = 0,
        },
        .{
            .autoinc_address = 0,
            .offset = @intFromEnum(
                esc.RegisterMap.rx_error_counter,
            ),
        },
        self.settings.recv_timeout_us,
    );
    std.log.info("bus wipe reset crc counters wkc: {}", .{wkc});

    // reset FMMUs
    wkc = try self.port.bwrPack(
        std.mem.zeroes(esc.FMMURegister),
        .{
            .autoinc_address = 0,
            .offset = @intFromEnum(
                esc.RegisterMap.FMMU0,
            ),
        },
        self.settings.recv_timeout_us,
    );
    std.log.info("bus wipe zero fmmus wkc: {}", .{wkc});

    // reset SMs
    wkc = try self.port.bwrPack(
        std.mem.zeroes(esc.SMRegister),
        .{
            .autoinc_address = 0,
            .offset = @intFromEnum(
                esc.RegisterMap.SM0,
            ),
        },
        self.settings.recv_timeout_us,
    );
    std.log.info("bus wipe zero sms wkc: {}", .{wkc});

    // TODO: reset DC activation
    // TODO: reset system time offsets
    // TODO: DC speedstart
    // TODO: DC filter

    // disable alias address
    wkc = try self.port.bwrPack(
        esc.DLControlEnableAliasAddressRegister{
            .enable_alias_address = false,
        },
        .{
            .autoinc_address = 0,
            .offset = @intFromEnum(esc.RegisterMap.DL_control_enable_alias_address),
        },
        self.settings.recv_timeout_us,
    );
    std.log.info("bus wipe disable alias wkc: {}", .{wkc});

    // request INIT
    wkc = try self.port.bwrPack(
        esc.ALControlRegister{
            .state = .INIT,

            // Ack errors not required for init transition.
            // Simple subdevices will copy the ack flag directly to the
            // error flag in the AL Status register.
            // Complex devices will not.
            //
            // Ref: IEC 61158-6-12:2019 6.4.1.1
            .ack = false,
            .request_id = false,
        },
        .{
            .autoinc_address = 0,
            .offset = @intFromEnum(esc.RegisterMap.AL_control),
        },
        self.settings.recv_timeout_us,
    );
    std.log.info("bus wipe INIT wkc: {}", .{wkc});

    // Force take away EEPROM from PDI
    wkc = try self.port.bwrPack(
        esc.SIIAccessRegisterCompact{
            .owner = .ethercat_DL,
            .lock = true,
        },
        .{
            .autoinc_address = 0,
            .offset = @intFromEnum(esc.RegisterMap.SII_access),
        },
        self.settings.recv_timeout_us,
    );
    std.log.info("bus wipe force eeprom wkc: {}", .{wkc});

    // Maindevice controls EEPROM
    wkc = try self.port.bwrPack(
        esc.SIIAccessRegisterCompact{
            .owner = .ethercat_DL,
            .lock = false,
        },
        .{
            .autoinc_address = 0,
            .offset = @intFromEnum(esc.RegisterMap.SII_access),
        },
        self.settings.recv_timeout_us,
    );
    std.log.info("bus wipe eeprom control to maindevice wkc: {}", .{wkc});

    // count subdevices
    const res = try self.port.brdPack(
        esc.ALStatusRegister,
        .{
            .autoinc_address = 0,
            .offset = @intFromEnum(esc.RegisterMap.AL_status),
        },
        self.settings.recv_timeout_us,
    );
    std.log.info("detected {} subdevices", .{res.wkc});
    if (res.wkc != self.subdevices.len) {
        std.log.err("Found {} subdevices, expected {}.", .{ res.wkc, self.subdevices.len });
        return error.WrongNumberOfSubDevices;
    }
    try self.broadcastStateChange(.INIT, change_timeout_us);
}

pub fn busPreop(self: *MainDevice, change_timeout_us: u32) !void {

    // perform IP tasks for each subdevice
    for (self.subdevices) |*subdevice| {
        try assignStationAddress(
            self.port,
            SubDevice.stationAddressFromRingPos(subdevice.runtime_info.ring_position),
            subdevice.runtime_info.ring_position,
            self.settings.recv_timeout_us,
        );
        try subdevice.transitionIP(
            self.port,
            self.settings.recv_timeout_us,
            self.settings.eeprom_timeout_us,
        );
    }

    try self.broadcastStateChange(.PREOP, change_timeout_us);
}

pub fn busSafeop(self: *MainDevice, change_timeout_us: u32) !void {
    // perform PS tasks for each subdevice
    for (self.subdevices) |*subdevice| {

        // TODO: assert non-overlapping FMMU configuration
        try subdevice.transitionPS(
            self.port,
            self.settings.recv_timeout_us,
            self.settings.eeprom_timeout_us,
            self.settings.mbx_timeout_us,
            subdevice.runtime_info.pi.inputs_area.start_addr,
            subdevice.runtime_info.pi.outputs_area.start_addr,
        );
    }

    const state_change_wkc = try self.port.bwrPack(
        esc.ALControlRegister{
            .state = .SAFEOP,
            .ack = false,
            .request_id = false,
        },
        .{
            .autoinc_address = 0,
            .offset = @intFromEnum(esc.RegisterMap.AL_control),
        },
        self.settings.recv_timeout_us,
    );
    if (state_change_wkc != self.subdevices.len) return error.Wkc;
    var timer = std.time.Timer.start() catch @panic("timer not supported");
    while (timer.read() < @as(u64, change_timeout_us) * std.time.ns_per_us) {
        const result = try self.sendRecvCyclicFramesDiag();
        if (result.brd_status_wkc != self.subdevices.len) return error.Wkc;
        if (result.brd_status.state == .SAFEOP and result.brd_status_wkc == self.subdevices.len) break;
    } else {
        for (self.subdevices) |subdevice| {
            const status = try subdevice.getALStatus(self.port, self.settings.recv_timeout_us);
            if (status.state != .SAFEOP) {
                std.log.err("station address: 0x{x} failed state transition, status: {}", .{ SubDevice.stationAddressFromRingPos(subdevice.runtime_info.ring_position), status });
            }
        }
        return error.StateChangeTimeout;
    }
}

pub fn busOp(self: *MainDevice, change_timeout_us: u32) !void {
    for (self.subdevices) |*subdevice| {
        try subdevice.transitionSO(
            self.port,
            self.settings.recv_timeout_us,
        );
    }

    const state_change_wkc = try self.port.bwrPack(
        esc.ALControlRegister{
            .state = .OP,
            .ack = false,
            .request_id = false,
        },
        .{
            .autoinc_address = 0,
            .offset = @intFromEnum(esc.RegisterMap.AL_control),
        },
        self.settings.recv_timeout_us,
    );
    if (state_change_wkc != self.subdevices.len) return error.Wkc;

    var timer = std.time.Timer.start() catch @panic("timer not supported");
    while (timer.read() < @as(u64, change_timeout_us) * std.time.ns_per_us) {
        const result = try self.sendRecvCyclicFramesDiag();
        // std.log.info("diag: {}", .{result});
        if (result.brd_status_wkc != self.subdevices.len) return error.Wkc;
        if (result.brd_status.state == .OP and result.brd_status_wkc == self.subdevices.len) {
            std.log.warn("successfull state change to {}, status code: {}", .{ result.brd_status.state, result.brd_status.status_code });
            break;
        }
    } else return error.StateChangeTimeout;
}

pub const SendRecvCyclicFramesError = SendRecvCycleFramesDiagError || error{
    NotAllSubdevicesInOP,
    TopologyChanged,
    Wkc,
};

pub fn sendRecvCyclicFrames(self: *MainDevice) SendRecvCyclicFramesError!void {
    const result = try self.sendRecvCyclicFramesDiag();
    if (result.brd_status_wkc != self.subdevices.len) return error.TopologyChanged;
    if (result.brd_status.state != .OP) return error.NotAllSubdevicesInOP;
    if (result.process_data_wkc != self.expectedProcessDataWkc()) return error.Wkc;
}

// TODO: rename this
pub const SendRecvCyclicFramesDiagResult = struct {
    brd_status: esc.ALStatusRegister,
    brd_status_wkc: u16,
    process_data_wkc: u16,
};

// TODO: rename this
pub const SendRecvCycleFramesDiagError = error{
    LinkError,
    CurruptedFrame,
    NoTransactionAvailable,
    RecvTimeout,
    /// TODO: can we get rid of this???
    NoTransactions,
};

/// returns number of frames required to exchange process data
pub fn frameCount(process_image_size: u32) u32 {
    var process_image_bytes_remaining = process_image_size;
    var used_frames: u32 = 0;
    const datagram_data_remaining_after_brd = 1468;
    comptime assert(datagram_data_remaining_after_brd == blk: {
        var builder = FrameBuilder{};
        builder.appendBrdPack(
            esc.ALStatusRegister,
            .{
                .autoinc_address = 0,
                .offset = @intFromEnum(esc.RegisterMap.AL_status),
            },
        ) catch |err| switch (err) {
            error.NoSpaceLeft => unreachable,
        };

        break :blk builder.datagramDataSpaceRemaining();
    });
    process_image_bytes_remaining -|= datagram_data_remaining_after_brd;
    used_frames += 1;
    if (process_image_bytes_remaining == 0) return used_frames;
    // TODO: use divCeil?
    const pure_lrw_frames = (process_image_bytes_remaining + telegram.Datagram.max_data_length - 1) / telegram.Datagram.max_data_length;
    process_image_bytes_remaining -|= pure_lrw_frames * telegram.Datagram.max_data_length;
    used_frames += pure_lrw_frames;
    assert(process_image_bytes_remaining == 0);
    return used_frames;
}

pub const max_frames_in_flight = std.math.maxInt(u8) + 1;

pub fn sendCyclicFrames(self: *MainDevice) !void {
    // TODO: reduce this spaghetti!
    assert(frameCount(@intCast(self.process_image.len)) <= self.frames.len);
    assert(self.transactions.len == 0); // did you try to send more than once before recv?

    // TODO: re-do frame identification to allow extremely large process data
    var process_image_bytes_remaining = self.process_image.len;
    var logical_addr: u32 = 0;

    var used_frames: u32 = 0;
    build_frames: for (0..max_frames_in_flight) |i| {
        var builder = FrameBuilder{};
        if (i == 0) {
            builder.appendBrdPack(
                esc.ALStatusRegister,
                .{
                    .autoinc_address = 0,
                    .offset = @intFromEnum(esc.RegisterMap.AL_status),
                },
            ) catch |err| switch (err) {
                error.NoSpaceLeft => unreachable,
            };
        }

        // append process data datagrams
        if (process_image_bytes_remaining > 0 and builder.datagramDataSpaceRemaining() > 0) {
            const bytes_to_consume = @min(process_image_bytes_remaining, builder.datagramDataSpaceRemaining());
            const start = logical_addr;
            const end_exclusive = logical_addr + bytes_to_consume;

            builder.appendLrw(logical_addr, self.process_image[start..end_exclusive]) catch |err| switch (err) {
                error.NoSpaceLeft => unreachable,
            };
            process_image_bytes_remaining -= bytes_to_consume;
            logical_addr += bytes_to_consume;
        }

        assert(i < self.frames.len); // checked by frameCount on init
        self.frames[i] = builder.dumpFrame();
        used_frames += 1;

        if (process_image_bytes_remaining == 0) break :build_frames;
    } else unreachable; // checked by frameCount on init
    assert(process_image_bytes_remaining == 0);
    assert(used_frames == frameCount(@intCast(self.process_image.len)));

    // send muliple frames in flight
    var transactions = std.BoundedArray(u8, max_frames_in_flight){};
    errdefer {
        for (transactions.slice()) |transaction| {
            self.port.release_transaction(transaction);
        }
    }
    assert(used_frames <= max_frames_in_flight);
    assert(used_frames <= self.frames.len);
    for (self.frames[0..used_frames]) |*frame| {
        const transaction_idx = try self.port.claim_transaction();

        transactions.append(transaction_idx) catch |err| switch (err) {
            error.Overflow => unreachable,
        };
        try self.port.send_transaction(transaction_idx, frame, frame);
    }
    self.transactions = transactions;

    if (self.first_cycle_time == null) {
        self.first_cycle_time = std.time.Instant.now() catch @panic("Timer unsupported.");
    }
    assert(self.first_cycle_time != null);
    assert(self.transactions.len > 0);
}

pub fn recvCyclicFrames(self: *MainDevice) SendRecvCycleFramesDiagError!SendRecvCyclicFramesDiagResult {
    // TODO: reduce this spaghetti!

    if (self.transactions.len == 0) return error.NoTransactions;
    defer assert(self.transactions.len == 0);
    errdefer {
        for (self.transactions.slice()) |transaction| {
            self.port.release_transaction(transaction);
        }
        self.transactions = .{};
    }
    const n_transactions = self.transactions.len;
    recv: for (0..(n_transactions * 2) + 1) |_| {
        if (self.transactions.len == 0) break :recv;
        const transaction = self.transactions.pop();
        if (try self.port.continue_transaction(transaction)) {
            self.port.release_transaction(transaction);
        } else {
            self.transactions.append(transaction) catch |err| switch (err) {
                error.Overflow => unreachable,
            };
        }
    } else {
        return error.RecvTimeout;
    }
    assert(self.transactions.len == 0);

    // TODO: use individual datagram WKC's
    var process_data_wkc: u16 = 0;
    for (self.frames[0..n_transactions]) |*frame| {
        for (frame.portable_datagrams.slice()) |*dgram| {
            switch (dgram.header.command) {
                .LRD, .LWR, .LRW => process_data_wkc +|= dgram.wkc,
                .BRD => {},
                else => unreachable,
            }
        }
    }

    // copy data to process image now that we know wkc is correct
    // telegram.EtherCATFrame.isCurrupted protects against memory
    // curruption
    // TODO: don't touch process data unless wkc is correct
    for (self.frames[0..n_transactions]) |*frame| {
        for (frame.datagrams().slice()) |*dgram| {
            switch (dgram.header.command) {
                .LRD, .LRW => {
                    const start = dgram.header.address;
                    const end_exclusive = dgram.header.address + dgram.data.len;
                    @memcpy(self.process_image[start..end_exclusive], dgram.data);
                },
                // no need to copy to outputs
                .BRD, .LWR => {},
                else => unreachable,
            }
        }
    }
    // check subdevice states
    assert(self.frames[0].portable_datagrams.slice()[0].header.command == .BRD);
    const state_check_dgram: telegram.Datagram = self.frames[0].datagrams().slice()[0];
    const brd_status_wkc = state_check_dgram.wkc;
    const al_status = wire.packFromECatSlice(esc.ALStatusRegister, state_check_dgram.data);

    return SendRecvCyclicFramesDiagResult{
        .brd_status = al_status,
        .brd_status_wkc = brd_status_wkc,
        .process_data_wkc = process_data_wkc,
    };
}

pub fn sendRecvCyclicFramesDiag(self: *MainDevice) SendRecvCycleFramesDiagError!SendRecvCyclicFramesDiagResult {
    try self.sendCyclicFrames();
    var timer = std.time.Timer.start() catch @panic("timer not supported");
    while (timer.read() < @as(u64, self.settings.recv_timeout_us) * std.time.ns_per_us) {
        const result = self.recvCyclicFrames() catch |err| switch (err) {
            error.RecvTimeout => continue,
            else => |err2| return err2,
        };
        return result;
    } else {
        return error.RecvTimeout;
    }
    unreachable;
}

pub fn broadcastStateChange(self: *MainDevice, state: esc.ALStateControl, change_timeout_us: u32) !void {
    const wkc = try self.port.bwrPack(
        esc.ALControlRegister{
            .state = state,
            // simple subdevices will copy the ack bit
            // into the AL status error bit.
            //
            // Ref: IEC 61158-6-12:2019 6.4.1.1
            .ack = false,
            .request_id = false,
        },
        .{
            .autoinc_address = 0,
            .offset = @intFromEnum(esc.RegisterMap.AL_control),
        },
        self.settings.recv_timeout_us,
    );
    if (wkc != self.subdevices.len) return error.Wkc;

    var timer = std.time.Timer.start() catch @panic("timer not supported");
    while (timer.read() < @as(u64, change_timeout_us) * std.time.ns_per_us) {
        const res = try self.port.brdPack(
            esc.ALStatusRegister,
            .{
                .autoinc_address = 0,
                .offset = @intFromEnum(esc.RegisterMap.AL_status),
            },
            self.settings.recv_timeout_us,
        );
        const brd_wkc = res.wkc;
        const status = res.ps;
        if (brd_wkc != self.subdevices.len) return error.Wkc;

        // we check if the actual state matches the requested
        // state before checking the error bit becuase simple subdevices
        // will just copy the ack bit to the error bit.
        //
        // Ref: IEC 61158-6-12:2019 6.4.1.1

        const requested_int: u4 = @intFromEnum(state);
        const actual_int: u4 = @intFromEnum(status.state);
        if (actual_int == requested_int) {
            std.log.warn(
                "successful broadcast state change to {}, Status Code: {}.",
                .{ status.state, status.status_code },
            );
            break;
        }
        if (status.err) {
            std.log.err(
                "broadcast state change refused to {}. Actual state: {}, Status Code: {}.",
                .{ state, status.state, status.status_code },
            );
            return error.StateChangeRefused;
        }
    } else {
        return error.StateChangeTimeout;
    }
}

pub fn expectedProcessDataWkc(self: *const MainDevice) u16 {
    var wkc: u16 = 0;
    for (self.subdevices) |subdevice| {
        if (subdevice.config.outputs_bit_length > 0) wkc += 2;
        if (subdevice.config.inputs_bit_length > 0) wkc += 1;
    }
    return wkc;
}

/// Assign configured station address.
pub fn assignStationAddress(port: *Port, station_address: u16, ring_position: u16, recv_timeout_us: u32) !void {
    const autoinc_address = SubDevice.autoincAddressFromRingPos(ring_position);
    try port.apwrPackWkc(
        esc.ConfiguredStationAddressRegister{
            .configured_station_address = station_address,
        },
        telegram.PositionAddress{
            .autoinc_address = autoinc_address,
            .offset = @intFromEnum(esc.RegisterMap.station_address),
        },
        recv_timeout_us,
        1,
    );
}

test {
    std.testing.refAllDecls(@This());
}
