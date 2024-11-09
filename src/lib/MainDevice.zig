const std = @import("std");
const assert = std.debug.assert;

const nic = @import("nic.zig");
const wire = @import("wire.zig");
const telegram = @import("telegram.zig");
const commands = @import("commands.zig");
const esc = @import("esc.zig");
const sii = @import("sii.zig");
const SubDevice = @import("SubDevice.zig");
const ENI = @import("ENI.zig");
const pdi = @import("pdi.zig");
const FrameBuilder = @import("FrameBuilder.zig");
const Port = @import("Port.zig");

const MainDevice = @This();

port: *Port,
settings: Settings,
eni: *const ENI,
subdevices: []SubDevice,
process_image: []u8,
frames: []telegram.EtherCATFrame,

pub const Settings = struct {
    recv_timeout_us: u32 = 2000,
    eeprom_timeout_us: u32 = 10000,
};

pub fn init(
    port: *Port,
    settings: Settings,
    eni: *const ENI,
    subdevices: []SubDevice,
    process_image: []u8,
    frames: []telegram.EtherCATFrame,
) !MainDevice {
    assert(eni.subdevices.len < 65537); // too many subdevices

    for (subdevices[0..eni.subdevices.len], eni.subdevices) |*subdevice, subdevice_config| {
        subdevice.* = SubDevice.init(subdevice_config);
    }
    try pdi.partitionProcessImage(process_image, subdevices[0..eni.subdevices.len]);
    return MainDevice{
        .port = port,
        .settings = settings,
        .eni = eni,
        .subdevices = subdevices,
        .process_image = process_image,
        .frames = frames,
    };
}

// pub fn validateENI(eni: *const ENI, pi_byte_length: usize) !void {
//     if (pi_byte_length > std.math.maxInt(u32)) return error.ProcessImageTooBig;

//     var pi_size_inputs_bytes: u32 = 0;
//     var pi_size_outputs_bytes: u32 = 0;

//     for (eni.subdevices) |subdevice| {}
// }

/// Initialize the ethercat bus.
///
/// Sets all subdevices to the INIT state.
/// Puts the bus in a known good starting configuration.
pub fn busINIT(self: *MainDevice, change_timeout_us: u32) !void {

    // open all ports
    var wkc = try commands.bwrPack(
        self.port,
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
    wkc = try commands.bwrPack(
        self.port,
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
    var zero_fmmus = wire.zerosFromPack(esc.FMMURegister);
    wkc = try commands.bwr(
        self.port,
        .{
            .autoinc_address = 0,
            .offset = @intFromEnum(
                esc.RegisterMap.FMMU0,
            ),
        },
        &zero_fmmus,
        self.settings.recv_timeout_us,
    );
    std.log.info("bus wipe zero fmmus wkc: {}", .{wkc});

    // reset SMs
    var zero_sms = wire.zerosFromPack(esc.SMRegister);
    wkc = try commands.bwr(
        self.port,
        .{
            .autoinc_address = 0,
            .offset = @intFromEnum(
                esc.RegisterMap.SM0,
            ),
        },
        &zero_sms,
        self.settings.recv_timeout_us,
    );
    std.log.info("bus wipe zero sms wkc: {}", .{wkc});

    // TODO: reset DC activation
    // TODO: reset system time offsets
    // TODO: DC speedstart
    // TODO: DC filter

    // disable alias address
    wkc = try commands.bwrPack(
        self.port,
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
    wkc = try commands.bwrPack(
        self.port,
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
    wkc = try commands.bwrPack(
        self.port,
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
    wkc = try commands.bwrPack(
        self.port,
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
    var dummy_data = [1]u8{0};
    wkc = try commands.brd(
        self.port,
        .{
            .autoinc_address = 0,
            .offset = 0,
        },
        &dummy_data,
        self.settings.recv_timeout_us,
    );
    std.log.info("detected {} subdevices", .{wkc});
    if (wkc != self.eni.subdevices.len) {
        std.log.err("Found {} subdevices, expected {}.", .{ wkc, self.eni.subdevices.len });
        return error.WrongNumberOfSubDevices;
    }

    wkc = 0;
    // command INIT on all subdevices, twice
    // SOEM does this...something about netX100
    for (0..1) |_| {
        wkc = try commands.bwrPack(
            self.port,
            esc.ALControlRegister{
                .state = .INIT,
                .ack = true, // ack errors
                .request_id = false,
            },
            .{
                .autoinc_address = 0,
                .offset = @intFromEnum(esc.RegisterMap.AL_control),
            },
            self.settings.recv_timeout_us,
        );
    }

    try self.broadcastStateChange(.INIT, change_timeout_us);
}

pub fn busPREOP(self: *MainDevice, change_timeout_us: u32) !void {

    // perform IP tasks for each subdevice
    for (self.subdevices[0..self.eni.subdevices.len], self.eni.subdevices) |*subdevice, subdevice_config| {
        try assignStationAddress(
            self.port,
            SubDevice.stationAddressFromRingPos(subdevice_config.ring_position),
            subdevice_config.ring_position,
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

pub fn busSAFEOP(self: *MainDevice, change_timeout_us: u32) !void {
    // perform PS tasks for each subdevice
    for (self.subdevices[0..self.eni.subdevices.len]) |*subdevice| {

        // TODO: assert non-overlapping FMMU configuration
        try subdevice.transitionPS(
            self.port,
            self.settings.recv_timeout_us,
            self.settings.eeprom_timeout_us,
            subdevice.runtime_info.pi.?.inputs_area.start_addr,
            subdevice.runtime_info.pi.?.outputs_area.start_addr,
        );
    }

    const state_change_wkc = try commands.bwrPack(
        self.port,
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
    if (state_change_wkc != self.eni.subdevices.len) return error.Wkc;
    var timer = std.time.Timer.start() catch @panic("timer not supported");
    while (timer.read() < @as(u64, change_timeout_us) * std.time.ns_per_us) {
        const result = try self.sendRecvCyclicFramesDiag();
        if (result.brd_status.state == .SAFEOP) break;
    } else return error.StateChangeTimeout;
}

pub fn busOP(self: *MainDevice, change_timeout_us: u32) !void {
    for (self.subdevices[0..self.eni.subdevices.len], self.eni.subdevices) |*subdevice, subdevice_config| {
        _ = subdevice_config;

        try subdevice.transitionSO(
            self.port,
            self.settings.recv_timeout_us,
        );
    }

    const state_change_wkc = try commands.bwrPack(
        self.port,
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
    if (state_change_wkc != self.eni.subdevices.len) return error.Wkc;

    var timer = std.time.Timer.start() catch @panic("timer not supported");
    while (timer.read() < @as(u64, change_timeout_us) * std.time.ns_per_us) {
        const result = try self.sendRecvCyclicFramesDiag();
        if (result.brd_status.state == .OP) break;
    } else return error.StateChangeTimeout;
}

pub fn sendRecvCyclicFrames(self: *MainDevice) !void {
    const result = try self.sendRecvCyclicFramesDiag();
    if (result.brd_status_wkc != self.eni.subdevices.len) return error.TopologyChanged;
    if (result.brd_status.state != .OP) return error.NotAllSubdevicesInOP;
    if (result.process_data_wkc != self.expectedProcessDataWkc()) return error.Wkc;
}

pub const SendRecvFramesDiagResult = struct {
    brd_status: esc.ALStatusRegister,
    brd_status_wkc: u16,
    process_data_wkc: u16,
};

pub fn sendRecvCyclicFramesDiag(self: *MainDevice) !SendRecvFramesDiagResult {

    // TODO: implement frame re-cycling upon receive to allow extremely large process data?
    // consume inputs
    var input_bytes_remaining = self.eni.processImageInputsSize();
    var output_bytes_remaining = self.eni.processImageOutputsSize();
    var logical_addr: u32 = 0;

    var used_frames: u9 = 0;
    build_frames: for (0..257) |i| {
        if (i == 256) return error.ProcessImageTooLarge;

        var builder = FrameBuilder{};
        if (i == 0) {
            try builder.appendBrdPack(
                esc.ALStatusRegister,
                .{
                    .autoinc_address = 0,
                    .offset = @intFromEnum(esc.RegisterMap.AL_status),
                },
            );
        }

        // append input datagrams
        if (input_bytes_remaining > 0 and builder.datagramDataSpaceRemaining() > 0) {
            const bytes_to_consume = @min(input_bytes_remaining, builder.datagramDataSpaceRemaining());
            const start = logical_addr;
            const end_exclusive = logical_addr + bytes_to_consume;
            try builder.appendLrw(logical_addr, self.process_image[start..end_exclusive]);
            input_bytes_remaining -= bytes_to_consume;
            logical_addr += bytes_to_consume;
        }

        // append output datagrams
        if (input_bytes_remaining == 0 and
            output_bytes_remaining > 0 and
            builder.datagramDataSpaceRemaining() > 0)
        {
            const bytes_to_consume = @min(output_bytes_remaining, builder.datagramDataSpaceRemaining());
            const start = logical_addr;
            const end_exclusive = logical_addr + bytes_to_consume;
            try builder.appendLrw(logical_addr, self.process_image[start..end_exclusive]);
            output_bytes_remaining -= bytes_to_consume;
            logical_addr += bytes_to_consume;
        }

        if (i > self.frames.len - 1) return error.NotEnoughFrames;
        self.frames[i] = builder.dumpFrame();
        used_frames += 1;

        if (input_bytes_remaining == 0 and output_bytes_remaining == 0) break :build_frames;
    }
    assert(input_bytes_remaining == 0);
    assert(output_bytes_remaining == 0);

    // send muliple frames in flight
    var transactions = std.BoundedArray(u8, 256){};
    defer {
        for (transactions.slice()) |transaction| {
            self.port.release_transaction(transaction);
        }
    }
    for (self.frames[0..used_frames]) |*frame| {
        const transaction_idx = try self.port.claim_transaction();
        transactions.append(transaction_idx) catch |err| switch (err) {
            error.Overflow => {
                self.port.release_transaction(transaction_idx);
                return error.Overflow;
            },
        };
        try self.port.send_transaction(transaction_idx, frame, frame);
    }

    // gather transactions (subject to recv timeout)
    var timer = std.time.Timer.start() catch @panic("timer not supported");
    recv: while (timer.read() < @as(u64, self.settings.recv_timeout_us) * std.time.ns_per_us) {
        if (transactions.len == 0) break :recv;
        const transaction = transactions.pop();
        if (try self.port.continue_transaction(transaction)) {
            self.port.release_transaction(transaction);
        } else {
            try transactions.append(transaction);
        }
    } else {
        return error.RecvTimeout;
    }

    // TODO: use individual datagram WKC's
    var process_data_wkc: u16 = 0;
    for (self.frames[0..used_frames]) |*frame| {
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
    // don't touch process data unless wkc is correct
    if (process_data_wkc == self.expectedProcessDataWkc()) {
        for (self.frames[0..used_frames]) |*frame| {
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
    }

    // check subdevice states
    assert(self.frames[0].portable_datagrams.slice()[0].header.command == .BRD);
    const state_check_dgram: telegram.Datagram = self.frames[0].datagrams().slice()[0];
    const brd_status_wkc = state_check_dgram.wkc;
    var fbs = std.io.fixedBufferStream(state_check_dgram.data);
    const reader = fbs.reader();
    const al_status = try wire.packFromECatReader(esc.ALStatusRegister, reader);
    return SendRecvFramesDiagResult{
        .brd_status = al_status,
        .brd_status_wkc = brd_status_wkc,
        .process_data_wkc = process_data_wkc,
    };
}

pub fn broadcastStateChange(self: *MainDevice, state: esc.ALStateControl, change_timeout_us: u32) !void {
    const wkc = try commands.bwrPack(
        self.port,
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
    if (wkc != self.eni.subdevices.len) return error.Wkc;

    var timer = std.time.Timer.start() catch @panic("timer not supported");
    while (timer.read() < @as(u64, change_timeout_us) * std.time.ns_per_us) {
        const res = try commands.brdPack(
            self.port,
            esc.ALStatusRegister,
            .{
                .autoinc_address = 0,
                .offset = @intFromEnum(esc.RegisterMap.AL_status),
            },
            self.settings.recv_timeout_us,
        );
        const brd_wkc = res.wkc;
        const status = res.ps;
        if (brd_wkc != self.eni.subdevices.len) return error.Wkc;

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

pub fn expectedProcessDataWkc(self: *MainDevice) u16 {
    var wkc: u16 = 0;
    for (self.eni.subdevices) |subdevice| {
        if (subdevice.outputs_bit_length > 0) wkc += 2;
        if (subdevice.inputs_bit_length > 0) wkc += 1;
    }
    return wkc;
}

/// Assign configured station address.
pub fn assignStationAddress(port: *Port, station_address: u16, ring_position: u16, recv_timeout_us: u32) !void {
    const autoinc_address = SubDevice.autoincAddressFromRingPos(ring_position);
    try commands.apwrPackWkc(
        port,
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
