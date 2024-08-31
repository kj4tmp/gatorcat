const std = @import("std");
const Port = @import("nic.zig").Port;
const telegram = @import("telegram.zig");
const eCatFromPack = @import("nic.zig").eCatFromPack;
const packFromECat = @import("nic.zig").packFromECat;
const zerosFromPack = @import("nic.zig").zerosFromPack;
const commands = @import("commands.zig");
const esc = @import("esc.zig");
const sii = @import("sii.zig");
const assert = std.debug.assert;
const config = @import("config.zig");
const SubdeviceRuntimeInfo = config.SubdeviceRuntimeInfo;
const SIIStream = @import("sii.zig").SIIStream;

pub const MainDeviceSettings = struct {
    recv_timeout_us: u32 = 2000,
    retries: u32 = 3,
    eeprom_timeout_us: u32 = 10000,
};

pub const MainDevice = struct {
    port: *Port,
    settings: MainDeviceSettings,
    bus_config: config.BusConfiguration,
    bus: []SubdeviceRuntimeInfo,

    pub fn init(
        port: *Port,
        settings: MainDeviceSettings,
        bus_config: config.BusConfiguration,
        bus: []SubdeviceRuntimeInfo,
    ) MainDevice {
        assert(bus_config.subdevices.len > 0); // no subdevices  in config
        assert(bus_config.subdevices.len < 65537); // too many subdevices

        return MainDevice{
            .port = port,
            .settings = settings,
            .bus_config = bus_config,
            .bus = bus,
        };
    }

    /// Initialize the ethercat bus.
    ///
    /// Sets all subdevices to the INIT state.
    pub fn bus_init(self: *MainDevice) !void {

        // TODO: should we allow time for port link detection?

        try self.bus_wipe();

        var wkc: u16 = 0;
        // command INIT on all subdevices, twice
        // SOEM does this...something about netX100
        for (0..1) |_| {
            wkc = try commands.BWR_ps(
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
        // count subdevices
        var dummy_data = [1]u8{0};
        wkc = try commands.BRD(
            self.port,
            .{
                .autoinc_address = 0,
                .offset = 0,
            },
            &dummy_data,
            self.settings.recv_timeout_us,
        );
        std.log.info("detected {} subdevices", .{wkc});
        if (wkc != self.bus_config.subdevices.len) {
            std.log.err("Found {} subdevices, expected {}.", .{ wkc, self.bus_config.subdevices.len });
            return error.WrongNumberOfSubdevices;
        }

        // assign configured station addresses
        var i: u16 = 0;
        while (i < self.bus_config.subdevices.len) : (i += 1) {
            const assigned_station_address = calc_station_addr(i);
            const autoinc_address = calc_autoinc_addr(i);
            wkc = try commands.APWR_ps(
                self.port,
                esc.ConfiguredStationAddressRegister{
                    .configured_station_address = assigned_station_address,
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
            } else {
                self.bus[i].station_address = assigned_station_address;
                self.bus[i].autoinc_address = autoinc_address;
            }
        }

        for (self.bus_config.subdevices, self.bus) |expected_subdevice, *runtime_info| {
            try self.subdevice_init(expected_subdevice, runtime_info);
        }

        // read state of subdevices
        var state_check = zerosFromPack(esc.ALStatusRegister);
        wkc = try commands.BRD(
            self.port,
            .{
                .autoinc_address = 0,
                .offset = @intFromEnum(esc.RegisterMap.AL_status),
            },
            &state_check,
            self.settings.recv_timeout_us,
        );
        const state_check_res = packFromECat(esc.ALStatusRegister, state_check);
        std.log.warn("state check: {}", .{state_check_res});

        // return wkc;
    }

    /// The maindevice should perform these tasks before commanding the IP transition in the subdevice.
    ///
    /// Clear FMMUs.
    /// Clear SMs.
    /// Set fixed physical address.
    /// Set SM0 for mailbox out.
    /// Set SM1 for mailbox in.
    ///
    /// If DCSupported, setup DC system time:
    /// Delay compensation
    /// Offset compensation
    /// Static drive compensation
    ///
    ///
    /// Ref: EtherCAT Device Protocol Poster
    fn subdevice_IP_tasks(self: *MainDevice, expected_subdevice: config.Subdevice, runtime_info: *SubdeviceRuntimeInfo) !void {
        assert(runtime_info.station_address != null); // should be set prior

        const info = try sii.readSIIFP_ps(
            self.port,
            sii.SubdeviceInfoCompact,
            runtime_info.station_address.?,
            @intFromEnum(sii.ParameterMap.PDI_control),
            self.settings.retries,
            self.settings.recv_timeout_us,
            self.settings.eeprom_timeout_us,
        );
        runtime_info.info = info;

        if (info.vendor_id != expected_subdevice.vendor_id or
            info.product_code != expected_subdevice.product_code or
            info.revision_number != expected_subdevice.revision_number)
        {
            std.log.err(
                "Identified subdevice: vendor id: 0x{x}, product code: 0x{x}, revision: 0x{x}, expected vendor id: 0x{x}, product code: 0x{x}, revision: 0x{x}",
                .{
                    info.vendor_id,
                    info.product_code,
                    info.revision_number,
                    expected_subdevice.vendor_id,
                    expected_subdevice.product_code,
                    expected_subdevice.revision_number,
                },
            );
            return error.UnexpectedSubdevice;
        }
        const dl_info_res = try commands.FPRD_ps(
            self.port,
            esc.DLInformationRegister,
            .{
                .station_address = runtime_info.station_address.?,
                .offset = @intFromEnum(esc.RegisterMap.DL_information),
            },
            self.settings.recv_timeout_us,
        );
        if (dl_info_res.wkc == 1) {
            runtime_info.dl_info = dl_info_res.ps;
        } else {
            return error.WKCError;
        }

        runtime_info.general = try sii.readGeneralCatagory(
            self.port,
            runtime_info.station_address.?,
            self.settings.retries,
            self.settings.recv_timeout_us,
            self.settings.eeprom_timeout_us,
        );

        if (runtime_info.general) |general| {
            runtime_info.order_id = try sii.readSIIString(
                self.port,
                runtime_info.station_address.?,
                general.order_idx,
                self.settings.retries,
                self.settings.recv_timeout_us,
                self.settings.eeprom_timeout_us,
            );

            runtime_info.name = try sii.readSIIString(
                self.port,
                runtime_info.station_address.?,
                general.name_idx,
                self.settings.retries,
                self.settings.recv_timeout_us,
                self.settings.eeprom_timeout_us,
            );

            // std.log.info("subdevice station addr: 0x{x}, general: {}", .{ runtime_info.station_address.?, general });
        }

        var order_id: ?[]const u8 = null;
        if (runtime_info.order_id) |order_id_array| {
            order_id = order_id_array.slice();
        }

        std.log.warn("0x{x}: {s}", .{ runtime_info.station_address.?, order_id orelse "null" });
        std.log.warn("    DCSupported: {}", .{runtime_info.dl_info.?.DCSupported});
        // TODO: topology
        // TODO: physical type
        // TODO: active ports

        // TODO: require transition to init

        // TODO: default mailbox configuration
        // TODO: SII
    }

    /// Put the bus in a known good starting configuration.
    fn bus_wipe(self: *MainDevice) !void {

        // open all ports
        var wkc = try commands.BWR_ps(
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
        wkc = try commands.BWR_ps(
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
        var zero_fmmus = zerosFromPack(esc.FMMURegister);
        wkc = try commands.BWR(
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
        var zero_sms = zerosFromPack(esc.SMRegister);
        wkc = try commands.BWR(
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
        wkc = try commands.BWR_ps(
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
        wkc = try commands.BWR_ps(
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
        std.log.info("bus wipe INIT wkc: {}", .{wkc});

        // Force take away EEPROM from PDI
        wkc = try commands.BWR_ps(
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
        wkc = try commands.BWR_ps(
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
    }
};

/// Calcuate the auto increment address of a subdevice
/// for commands which use position addressing.
///
/// The position parameter is the the subdevice's position
/// in the ethercat bus. 0 is the first subdevice.
fn calc_autoinc_addr(position: u16) u16 {
    var rval: u16 = 0;
    rval -%= position;
    return rval;
}

test "calc_autoinc_addr" {
    std.testing.expectEqual(@as(u16, 0), calc_autoinc_addr(0));
    std.testing.expectEqual(@as(u16, 65535), calc_autoinc_addr(1));
    std.testing.expectEqual(@as(u16, 65534), calc_autoinc_addr(2));
    std.testing.expectEqual(@as(u16, 65533), calc_autoinc_addr(3));
    std.testing.expectEqual(@as(u16, 65532), calc_autoinc_addr(4));
}

/// Calcuate the station address of a subdevice
/// for commands which use station addressing.
///
/// The position parameter is the subdevice's position
/// inthe ethercat bus. 0 is the first subdevice.
fn calc_station_addr(position: u16) u16 {
    return 0x1000 +% position;
}
