//! Bus scanner. Facilitates gathering information about the subdevices
//! on the bus without prior configuratiion.
const std = @import("std");
const Timer = std.time.Timer;
const ns_per_us = std.time.ns_per_us;

const commands = @import("commands.zig");
const esc = @import("esc.zig");
const MainDevice = @import("MainDevice.zig");
const nic = @import("nic.zig");
const Port = @import("Port.zig");
const sii = @import("sii.zig");
const SubDevice = @import("SubDevice.zig");
const wire = @import("wire.zig");

const Scanner = @This();

port: *Port,
settings: MainDevice.Settings,

pub fn init(port: *Port, settings: MainDevice.Settings) Scanner {
    return Scanner{
        .port = port,
        .settings = settings,
    };
}

pub fn countSubdevices(self: *const Scanner) !u16 {
    var dummy_data = [1]u8{0};
    const wkc = try commands.brd(
        self.port,
        .{
            .autoinc_address = 0,
            .offset = 0,
        },
        &dummy_data,
        self.settings.recv_timeout_us,
    );
    return wkc;
}

pub fn busINIT(self: *const Scanner, state_change_timeout_us: u32, subdevice_count: u16) !void {

    // open all ports
    try commands.bwrPackWkc(
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
        subdevice_count,
    );

    // TODO: set IRQ mask

    // reset CRC counters
    try commands.bwrPackWkc(
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
        subdevice_count,
    );

    // reset FMMUs
    try commands.bwrPackWkc(
        self.port,
        std.mem.zeroes(esc.FMMURegister),
        .{ .autoinc_address = 0, .offset = @intFromEnum(esc.RegisterMap.FMMU0) },
        self.settings.recv_timeout_us,
        subdevice_count,
    );

    // reset SMs
    try commands.bwrPackWkc(
        self.port,
        std.mem.zeroes(esc.SMRegister),
        .{ .autoinc_address = 0, .offset = @intFromEnum(esc.RegisterMap.SM0) },
        self.settings.recv_timeout_us,
        subdevice_count,
    );

    // TODO: reset DC activation
    // TODO: reset system time offsets
    // TODO: DC speedstart
    // TODO: DC filter

    // disable alias address
    try commands.bwrPackWkc(
        self.port,
        esc.DLControlEnableAliasAddressRegister{
            .enable_alias_address = false,
        },
        .{ .autoinc_address = 0, .offset = @intFromEnum(esc.RegisterMap.DL_control_enable_alias_address) },
        self.settings.recv_timeout_us,
        subdevice_count,
    );

    // request INIT
    try commands.bwrPackWkc(
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
        subdevice_count,
    );

    // Force take away EEPROM from PDI
    try commands.bwrPackWkc(
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
        subdevice_count,
    );

    // Maindevice controls EEPROM
    try commands.bwrPackWkc(
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
        subdevice_count,
    );

    // command INIT on all subdevices, twice
    // SOEM does this...something about netX100
    for (0..1) |_| {
        commands.bwrPackWkc(
            self.port,
            esc.ALControlRegister{
                .state = .INIT,
                .ack = false,
                .request_id = false,
            },
            .{
                .autoinc_address = 0,
                .offset = @intFromEnum(esc.RegisterMap.AL_control),
            },
            self.settings.recv_timeout_us,
            subdevice_count,
        ) catch |err| switch (err) {
            error.Wkc => continue, // this happens a lot
            else => |err_subset| return err_subset,
        };
    }

    try self.broadcastALStatusCheck(subdevice_count, .INIT, state_change_timeout_us);
}

pub fn subdevicePREOP(self: *Scanner, change_timeout_us: u32, ring_position: u16) !SubDevice {
    const station_address = SubDevice.stationAddressFromRingPos(@intCast(ring_position));
    const info = try sii.readSIIFP_ps(
        self.port,
        sii.SubDeviceInfoCompact,
        station_address,
        @intFromEnum(sii.ParameterMap.PDI_control),
        self.settings.recv_timeout_us,
        self.settings.eeprom_timeout_us,
    );

    var fake_process_data: [1]u8 = .{0};
    var subdevice = SubDevice.init(
        .{
            .identity = .{
                .vendor_id = info.vendor_id,
                .product_code = info.product_code,
                .revision_number = info.revision_number,
            },
            .auto_config = .auto,
            .inputs_bit_length = 0,
            .outputs_bit_length = 0,
        },
        @intCast(ring_position),
        .{
            .inputs = fake_process_data[0..0],
            .inputs_area = .{ .start_addr = 0, .bit_length = 0 },
            .outputs = fake_process_data[0..0],
            .outputs_area = .{ .start_addr = 0, .bit_length = 0 },
        },
    );
    try subdevice.transitionIP(
        self.port,
        self.settings.recv_timeout_us,
        self.settings.eeprom_timeout_us,
    );

    try subdevice.setALState(self.port, .PREOP, change_timeout_us, self.settings.recv_timeout_us);

    return subdevice;
}

pub fn broadcastALStatusCheck(
    self: *const Scanner,
    subdevice_count: ?u16,
    state: esc.ALStateStatus,
    change_timeout_us: u32,
) !void {
    var timer = Timer.start() catch |err| switch (err) {
        error.TimerUnsupported => unreachable,
    };

    while (timer.read() < @as(u64, change_timeout_us) * ns_per_us) {
        const status_res = try commands.brdPack(
            self.port,
            esc.ALStatusRegister,
            .{
                .autoinc_address = 0,
                .offset = @intFromEnum(esc.RegisterMap.AL_status),
            },
            self.settings.recv_timeout_us,
        );

        if (subdevice_count) |expected_wkc| {
            if (status_res.wkc != expected_wkc) return error.Wkc;
        }
        const status = status_res.ps;

        if (status.state == state) {
            return;
        }
        if (status.err) {
            std.log.err("state change refused. status: {}", .{status});
            return error.StateChangeRefused;
        }
    } else {
        return error.StateChangeTimeout;
    }
    unreachable;
}

pub fn assignStationAddresses(self: *const Scanner, subdevice_count: u16) !void {
    for (0..subdevice_count) |i| {
        try MainDevice.assignStationAddress(self.port, SubDevice.stationAddressFromRingPos(@intCast(i)), @intCast(i), self.settings.recv_timeout_us);
    }
}
