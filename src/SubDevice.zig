const std = @import("std");
const Timer = std.time.Timer;
const ns_per_us = std.time.ns_per_us;
const assert = std.debug.assert;

const esc = @import("esc.zig");
const nic = @import("nic.zig");
const commands = @import("commands.zig");
const sii = @import("sii.zig");
const telegram = @import("telegram.zig");
const wire = @import("wire.zig");
const coe = @import("mailbox/coe.zig");
const mailbox = @import("mailbox.zig");
const ENI = @import("ENI.zig");

runtime_info: RuntimeInfo = .{},
prior_info: ENI.SubDeviceConfiguration,

pub fn init(prior_info: ENI.SubDeviceConfiguration) SubDevice {
    return SubDevice{
        .prior_info = prior_info,
    };
}

// info gathered at runtime from bus,
// will be filled in when available
pub const RuntimeInfo = struct {
    status: ?esc.ALStatusRegister = null,

    /// DL Info from ESC
    dl_info: ?esc.DLInformationRegister = null,

    /// first part of the SII
    info: ?sii.SubDeviceInfoCompact = null,

    /// SII General Catagory
    general: ?sii.CatagoryGeneral = null,

    /// Syncmanager configurations
    sms: ?esc.SMRegister = null,

    /// FMMU configurations
    fmmus: ?sii.FMMUCatagory = null,

    /// name string from the SII
    name: ?sii.SIIString = null,
    /// order id from the SII, ex: EK1100
    order_id: ?sii.SIIString = null,
    cnt: coe.Cnt = coe.Cnt{},
};

const SubDevice = @This();

pub fn setALState(
    self: *const SubDevice,
    port: *nic.Port,
    state: esc.ALStateControl,
    change_timeout_us: u32,
    recv_timeout_us: u32,
) !void {
    // TODO: consider not using the ack bit
    const station_address: u16 = self.prior_info.station_address;

    const wkc = try commands.fpwrPack(
        port,
        esc.ALControlRegister{
            .state = state,
            // simple subdevices will copy the ack bit
            // into the AL status error bit.
            //
            // Ref: IEC 61158-6-12:2019 6.4.1.1
            .ack = true,
            .request_id = false,
        },
        .{
            .station_address = station_address,
            .offset = @intFromEnum(esc.RegisterMap.AL_control),
        },
        recv_timeout_us,
    );
    if (wkc != 1) {
        return error.Wkc;
    }

    var timer = Timer.start() catch |err| switch (err) {
        error.TimerUnsupported => unreachable,
    };

    while (timer.read() < change_timeout_us * ns_per_us) {
        const status = try commands.fprdPackWkc(
            port,
            esc.ALStatusRegister,
            .{
                .station_address = station_address,
                .offset = @intFromEnum(esc.RegisterMap.AL_status),
            },
            recv_timeout_us,
            1,
        );

        // we check if the actual state matches the requested
        // state before checking the error bit becuase simple subdevices
        // will just copy the ack bit to the error bit.
        //
        // Ref: IEC 61158-6-12:2019 6.4.1.1

        const requested_int: u4 = @intFromEnum(state);
        const actual_int: u4 = @intFromEnum(status.state);
        if (actual_int == requested_int) {
            std.log.info(
                "station addr: 0x{x}, successful state change to {}, Status Code: {}.",
                .{ station_address, status.state, status.status_code },
            );
            return;
        }
        if (status.err) {
            std.log.err(
                "station addr: 0x{x}, refused state change to {}. Actual state: {}, Status Code: {}.",
                .{ station_address, state, status.state, status.status_code },
            );
            return error.StateChangeRefused;
        }
    } else {
        return error.StateChangeTimeout;
    }
    unreachable;
}

/// The maindevice should perform these tasks before commanding the IP transition in the subdevice.
///
/// [x] Set configured station address (also called "fixed physical address").
///
/// [x] Check subdevice identity.
///
/// [x] Clear FMMUs.
/// [x] Clear SMs.
/// [x] Set SM0 for mailbox out.
/// [x] Set SM1 for mailbox in.
///
/// TODO: If DCSupported, setup DC system time:
/// [ ] Delay compensation
/// [ ] Offset compensation
/// [ ] Static drift compensation
///
///
/// Ref: EtherCAT Device Protocol Poster
pub fn transitionIP(
    self: *SubDevice,
    port: *nic.Port,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
) !void {
    const station_address = self.prior_info.station_address;
    // check subdevice identity
    const info = try sii.readSIIFP_ps(
        port,
        sii.SubDeviceInfoCompact,
        station_address,
        @intFromEnum(sii.ParameterMap.PDI_control),
        recv_timeout_us,
        eeprom_timeout_us,
    );
    self.runtime_info.info = info;

    if (info.vendor_id != self.prior_info.identity.vendor_id or
        info.product_code != self.prior_info.identity.product_code or
        info.revision_number != self.prior_info.identity.revision_number)
    {
        std.log.err(
            "Identified subdevice: vendor id: 0x{x}, product code: 0x{x}, revision: 0x{x}, expected vendor id: 0x{x}, product code: 0x{x}, revision: 0x{x}",
            .{
                info.vendor_id,
                info.product_code,
                info.revision_number,
                self.prior_info.identity.vendor_id,
                self.prior_info.identity.product_code,
                self.prior_info.identity.revision_number,
            },
        );
        return error.UnexpectedSubDevice;
    }
    const dl_info_res = try commands.fprdPack(
        port,
        esc.DLInformationRegister,
        .{
            .station_address = station_address,
            .offset = @intFromEnum(esc.RegisterMap.DL_information),
        },
        recv_timeout_us,
    );
    if (dl_info_res.wkc == 1) {
        self.runtime_info.dl_info = dl_info_res.ps;
    } else {
        return error.WKCError;
    }

    self.runtime_info.general = try sii.readGeneralCatagory(
        port,
        station_address,
        recv_timeout_us,
        eeprom_timeout_us,
    );

    if (self.runtime_info.general) |general| {
        self.runtime_info.order_id = try sii.readSIIString(
            port,
            station_address,
            general.order_idx,
            recv_timeout_us,
            eeprom_timeout_us,
        );

        self.runtime_info.name = try sii.readSIIString(
            port,
            station_address,
            general.name_idx,
            recv_timeout_us,
            eeprom_timeout_us,
        );

        // std.log.info("subdevice station addr: 0x{x}, general: {}", .{ runtime_info.station_address.?, general });
    }

    var order_id: ?[]const u8 = null;
    if (self.runtime_info.order_id) |order_id_array| {
        order_id = order_id_array.slice();
    }

    // reset FMMUs
    var zero_fmmus = wire.zerosFromPack(esc.FMMURegister);
    var wkc = try commands.fpwr(
        port,
        .{
            .station_address = station_address,
            .offset = @intFromEnum(
                esc.RegisterMap.FMMU0,
            ),
        },
        &zero_fmmus,
        recv_timeout_us,
    );
    if (wkc != 1) {
        return error.WKCError;
    }

    // reset SMs
    var zero_sms = wire.zerosFromPack(esc.SMRegister);
    wkc = try commands.fpwr(
        port,
        .{
            .station_address = station_address,
            .offset = @intFromEnum(
                esc.RegisterMap.SM0,
            ),
        },
        &zero_sms,
        recv_timeout_us,
    );
    if (wkc != 1) {
        return error.WKCError;
    }

    // Set default syncmanager configurations from sii info section

    // Set default syncmanager configurations.
    // If mailbox is supported:
    // SM0 should be used for Mailbox Out (from maindevice to subdevice)
    // SM1 should be used for Mailbox In (from subdevice to maindevice)
    self.runtime_info.sms = std.mem.zeroes(esc.SMRegister);
    if (info.std_recv_mbx_offset > 0) { // mbx supported?
        self.runtime_info.sms.?.SM0 = esc.SyncManagerAttributes.mbxOutDefaults(
            info.std_recv_mbx_offset,
            info.std_recv_mbx_size,
        );
        self.runtime_info.sms.?.SM1 = esc.SyncManagerAttributes.mbxInDefaults(
            info.std_send_mbx_offset,
            info.std_send_mbx_size,
        );
    }
    // Set SM from SII SM section if it exists
    const sii_sms = try sii.readSMCatagory(
        port,
        station_address,
        recv_timeout_us,
        eeprom_timeout_us,
    );
    if (sii_sms) |sms| {
        self.runtime_info.sms = sii.escSMsFromSIISMs(sms.slice());
    }

    // write SM configuration to subdevice
    wkc = try commands.fpwrPack(
        port,
        self.runtime_info.sms.?,
        .{
            .station_address = station_address,
            .offset = @intFromEnum(esc.RegisterMap.SM0),
        },
        recv_timeout_us,
    );
    if (wkc != 1) {
        return error.WKCError;
    }

    // TODO: FMMUs
    self.runtime_info.fmmus = try sii.readFMMUCatagory(
        port,
        station_address,
        recv_timeout_us,
        eeprom_timeout_us,
    );
    // std.log.info("sii fmmus: {any}", .{
    //     std.json.fmt(runtime_info.fmmus, .{
    //         .whitespace = .indent_4,
    //     }),
    // });

    // TODO: topology
    // TODO: physical type
    // TODO: active ports

    // TODO: require transition to init

    std.log.info("0x{x}: {s}", .{ station_address, order_id orelse "null" });
    std.log.info("    vendor_id: 0x{x}", .{self.runtime_info.info.?.vendor_id});
    std.log.info("    product_code: 0x{x}", .{self.runtime_info.info.?.product_code});
    std.log.info("    revision_number: 0x{x}", .{self.runtime_info.info.?.revision_number});
    std.log.info("    protocols: AoE: {}, EoE: {}, CoE: {}, FoE: {}, SoE: {}, VoE: {}", .{
        self.runtime_info.info.?.mbx_protocol.AoE,
        self.runtime_info.info.?.mbx_protocol.EoE,
        self.runtime_info.info.?.mbx_protocol.CoE,
        self.runtime_info.info.?.mbx_protocol.FoE,
        self.runtime_info.info.?.mbx_protocol.SoE,
        self.runtime_info.info.?.mbx_protocol.VoE,
    });
    std.log.info(
        "    mbx_recv: offset: 0x{x}, size: {}",
        .{
            self.runtime_info.info.?.std_recv_mbx_offset,
            self.runtime_info.info.?.std_recv_mbx_size,
        },
    );
    std.log.info(
        "    mbx_send: offset: 0x{x}, size: {}",
        .{
            self.runtime_info.info.?.std_send_mbx_offset,
            self.runtime_info.info.?.std_send_mbx_size,
        },
    );
    std.log.info("    DCSupported: {}", .{self.runtime_info.dl_info.?.DCSupported});

    // cant do startup parameters until mailbox is initialized
    try self.doStartupParameters(port, .IP, recv_timeout_us);
}

/// The maindevice should perform these tasks before commanding the PS transision.
///
/// [x] Set configuration objects via SDO.
/// [ ] Set RxPDO / TxPDO Assignment.
/// [ ] Set RxPDO / TxPDO Mapping.
/// [ ] Set SM2 for outputs.
/// [ ] Set SM3 for inputs.
/// [ ] Set FMMU0 (map outputs).
/// [ ] Set FMMU1 (map inputs).
///
/// If DC:
/// [ ] Configure SYNC/LATCH unit.
/// [ ] Set SYNC cycle time.
/// [ ] Set DC start time.
/// [ ] Set DC SYNC OUT unit.
/// [ ] Set DC LATCH IN unit.
/// [ ] Start continuous drift compensation.
///
/// Start:
/// [ ] Cyclic Process Data
/// [ ] Provide valid inputs
///
/// Ref: EtherCAT Device Protocol Poster
pub fn transitionPS(
    self: *SubDevice,
    port: *nic.Port,
    recv_timeout_us: u32,
) !void {
    // if CoE is supported, the subdevice PDOs can be mapped using information
    // from CoE. otherwise it can be obtained from the SII.
    // Ref: IEC 61158-5-12:2019 6.1.1.1
    // TODO: does it say somewhere that if CoE supported the PDOs MUST be in the CoE?

    try self.doStartupParameters(port, .PS, recv_timeout_us);

    // The PDOs can be read using SII or CoE.
    // We first read the configuration from SII and use that. If CoE is supported,
    // we read that and it overwrites whatever we got from SII.
    // read PDOs from SII

    // configure PDOs from CoE

    // TODO: configure PDOs from SoE

}

pub fn doStartupParameters(
    self: *SubDevice,
    port: *nic.Port,
    transition: ENI.Transition,
    recv_timeout_us: u32,
) !void {
    const parameters = self.prior_info.coe_startup_parameters orelse return;
    for (parameters) |parameter| {
        // TODO: support reads?
        if (parameter.transition == transition) {
            std.log.info("station address: 0x{x}, doing startup parameter: {}", .{ self.prior_info.station_address, parameter });

            try self.sdoWrite(
                port,
                parameter.data,
                parameter.index,
                parameter.subindex,
                parameter.complete_access,
                recv_timeout_us,
                parameter.timeout_us,
            );
        }
    }
}

pub fn sdoWrite(
    self: *SubDevice,
    port: *nic.Port,
    buf: []const u8,
    index: u16,
    subindex: u8,
    complete_access: bool,
    recv_timeout_us: u32,
    mbx_timeout_us: u32,
) !void {
    const info = self.runtime_info.info orelse return error.InvalidRuntimeInfo;
    const station_address = self.prior_info.station_address;
    const sms = self.runtime_info.sms orelse return error.InvalidRuntimeInfo;

    // subdevice supports CoE?
    if (!info.mbx_protocol.CoE or
        sms.SM0.physical_start_address == 0 or
        sms.SM0.length == 0 or
        sms.SM1.physical_start_address == 0 or
        sms.SM1.length == 0) return error.CoENotSupported;

    // supports complete access?
    if (self.runtime_info.general) |general| {
        if (!general.coe_details.enable_SDO_complete_access and complete_access) {
            return error.CompleteAccessNotSupported;
        }
    }

    // TODO: move this into runtime info
    // SM1 is mailbox in
    // SM0 is mailbox out
    const config = try mailbox.Configuration.init(
        sms.SM1.physical_start_address,
        sms.SM1.length,
        sms.SM0.physical_start_address,
        sms.SM0.length,
    );

    return try coe.sdoWrite(
        port,
        station_address,
        index,
        subindex,
        complete_access,
        buf,
        recv_timeout_us,
        mbx_timeout_us,
        self.runtime_info.cnt.nextCnt(),
        config,
        null,
    );
}

pub fn sdoRead(
    self: *SubDevice,
    port: *nic.Port,
    out: []u8,
    index: u16,
    subindex: u8,
    complete_access: bool,
    recv_timeout_us: u32,
    mbx_timeout_us: u32,
) !usize {
    const info = self.runtime_info.info orelse return error.InvalidRuntimeInfo;
    const station_address = self.prior_info.station_address;
    const sms = self.runtime_info.sms orelse return error.InvalidRuntimeInfo;

    // subdevice supports CoE?
    if (!info.mbx_protocol.CoE or
        sms.SM0.physical_start_address == 0 or
        sms.SM0.length == 0 or
        sms.SM1.physical_start_address == 0 or
        sms.SM1.length == 0) return error.CoENotSupported;

    // supports complete access?
    if (self.runtime_info.general) |general| {
        if (!general.coe_details.enable_SDO_complete_access and complete_access) {
            return error.CompleteAccessNotSupported;
        }
    }

    // TODO: move this into runtime info
    // SM1 is mailbox in
    // SM0 is mailbox out
    const config = try mailbox.Configuration.init(
        sms.SM1.physical_start_address,
        sms.SM1.length,
        sms.SM0.physical_start_address,
        sms.SM0.length,
    );

    return try coe.sdoRead(
        port,
        station_address,
        index,
        subindex,
        complete_access,
        out,
        recv_timeout_us,
        mbx_timeout_us,
        self.runtime_info.cnt.nextCnt(),
        config,
        null,
    );
}
