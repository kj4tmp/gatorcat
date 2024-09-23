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

const MainDevice = @This();

port: *nic.Port,
settings: Settings,
eni: ENI,
subdevices: []SubDevice,

pub const Settings = struct {
    recv_timeout_us: u32 = 2000,
    retries: u8 = 3,
    eeprom_timeout_us: u32 = 10000,
};

pub fn init(
    port: *nic.Port,
    settings: Settings,
    eni: ENI,
    subdevices: []SubDevice,
) MainDevice {
    assert(eni.subdevices.len > 0); // no subdevices  in config
    assert(eni.subdevices.len < 65537); // too many subdevices

    for (subdevices[0..eni.subdevices.len], eni.subdevices) |*subdevice, subdevice_config| {
        subdevice.* = SubDevice.init(subdevice_config);
    }
    return MainDevice{
        .port = port,
        .settings = settings,
        .eni = eni,
        .subdevices = subdevices,
    };
}

/// Initialize the ethercat bus.
///
/// Sets all subdevices to the INIT state.
/// Puts the bus in a known good starting configuration.
pub fn busINIT(self: *MainDevice) !void {

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
}

pub fn busPREOP(self: *MainDevice) !void {

    // perform IP tasks for each subdevice
    for (self.subdevices[0..self.eni.subdevices.len], self.eni.subdevices) |*subdevice, subdevice_config| {
        try self.assignStationAddress(subdevice_config.station_address, subdevice_config.ring_position);
        try subdevice.transitionIP(
            self.port,
            self.settings.retries,
            self.settings.recv_timeout_us,
            self.settings.eeprom_timeout_us,
        );
        try subdevice.setALState(
            self.port,
            .PREOP,
            30000,
            self.settings.recv_timeout_us,
        );
    }

    // read state of subdevices
    var state_check = wire.zerosFromPack(esc.ALStatusRegister);
    _ = try commands.brd(
        self.port,
        .{
            .autoinc_address = 0,
            .offset = @intFromEnum(esc.RegisterMap.AL_status),
        },
        &state_check,
        self.settings.recv_timeout_us,
    );
    const state_check_res = wire.packFromECat(esc.ALStatusRegister, state_check);
    std.log.warn("state check: {}", .{state_check_res});

    // return wkc;
}

pub fn busSAFEOP(self: *MainDevice) !void {
    _ = self;
}

/// Assign configured station address.
fn assignStationAddress(self: *MainDevice, station_address: u16, ring_position: u16) !void {
    const autoinc_address = calc_autoinc_addr(ring_position);
    const wkc = try commands.apwrPack(
        self.port,
        esc.ConfiguredStationAddressRegister{
            .configured_station_address = station_address,
        },
        telegram.PositionAddress{
            .autoinc_address = autoinc_address,
            .offset = @intFromEnum(esc.RegisterMap.station_address),
        },
        self.settings.recv_timeout_us,
    );
    if (wkc != 1) {
        std.log.err("WKCError on station address config: expected wkc 1, got {}.", .{wkc});
        return error.WKCError;
    }
}

/// Calcuate the auto increment address of a subdevice
/// for commands which use position addressing.
///
/// The position parameter is the the subdevice's position
/// in the ethercat bus. 0 is the first subdevice.
pub fn calc_autoinc_addr(ring_position: u16) u16 {
    var rval: u16 = 0;
    rval -%= ring_position;
    return rval;
}

test "calc_autoinc_addr" {
    try std.testing.expectEqual(@as(u16, 0), calc_autoinc_addr(0));
    try std.testing.expectEqual(@as(u16, 65535), calc_autoinc_addr(1));
    try std.testing.expectEqual(@as(u16, 65534), calc_autoinc_addr(2));
    try std.testing.expectEqual(@as(u16, 65533), calc_autoinc_addr(3));
    try std.testing.expectEqual(@as(u16, 65532), calc_autoinc_addr(4));
}

/// Calcuate the station address of a subdevice
/// for commands which use station addressing.
///
/// The position parameter is the subdevice's position
/// inthe ethercat bus. 0 is the first subdevice.
pub fn calc_station_addr(position: u16) u16 {
    return 0x1000 +% position;
}
