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
const pdi = @import("pdi.zig");

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
    /// CoE information, null if CoE not supported
    coe: ?CoE = null,

    /// process image
    pi: ?ProcessImage = null,

    pub const ProcessImage = struct {
        inputs: []u8,
        inputs_area: pdi.LogicalMemoryArea,
        outputs: []u8,
        outputs_area: pdi.LogicalMemoryArea,
    };

    pub const CoE = struct {
        config: mailbox.Configuration,
        supports_complete_access: bool,
        cnt: coe.Cnt = coe.Cnt{},
    };
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

    while (timer.read() < @as(u64, change_timeout_us) * ns_per_us) {
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
    _ = self.runtime_info.pi orelse return error.InvalidRuntimeInfo;

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

    const general_catagory = try sii.readGeneralCatagory(
        port,
        station_address,
        recv_timeout_us,
        eeprom_timeout_us,
    );

    // wipe FMMUs
    var zero_fmmus = wire.zerosFromPack(esc.FMMURegister);
    try commands.fpwrWkc(
        port,
        .{
            .station_address = station_address,
            .offset = @intFromEnum(
                esc.RegisterMap.FMMU0,
            ),
        },
        &zero_fmmus,
        recv_timeout_us,
        1,
    );

    // wipe SMs
    var zero_sms = wire.zerosFromPack(esc.SMRegister);
    try commands.fpwrWkc(
        port,
        .{
            .station_address = station_address,
            .offset = @intFromEnum(
                esc.RegisterMap.SM0,
            ),
        },
        &zero_sms,
        recv_timeout_us,
        1,
    );

    // configure sync managers.
    // during the IP transition, we should configure the mailbox sync managers.
    var sms = std.mem.zeroes(esc.SMRegister);
    switch (self.prior_info.auto_config) {
        .none => {},
        .sii => {
            // If mailbox is supported:
            // SM0 should be used for Mailbox Out (from maindevice to subdevice)
            // SM1 should be used for Mailbox In (from subdevice to maindevice)
            if (info.std_recv_mbx_offset > 0) { // mbx supported?
                sms.SM0 = esc.SyncManagerAttributes.mbxOutDefaults(
                    info.std_recv_mbx_offset,
                    info.std_recv_mbx_size,
                );
                sms.SM1 = esc.SyncManagerAttributes.mbxInDefaults(
                    info.std_send_mbx_offset,
                    info.std_send_mbx_size,
                );
            }

            // supports CoE? Complete Access?
            if (info.mbx_protocol.CoE) {
                self.runtime_info.coe = RuntimeInfo.CoE{
                    .config = try mailbox.Configuration.init(
                        sms.SM1.physical_start_address,
                        sms.SM1.length,
                        sms.SM0.physical_start_address,
                        sms.SM0.length,
                    ),
                    .supports_complete_access = blk: {
                        if (general_catagory) |general| {
                            break :blk general.coe_details.enable_SDO_complete_access;
                        } else break :blk false;
                    },
                };
            }

            // Trust default syncmanager configurations from sii
            // Set SM from SII SM section if it exists
            var maybe_sii_sms = try sii.readSMCatagory(
                port,
                station_address,
                recv_timeout_us,
                eeprom_timeout_us,
            );
            // apparently the SII doesnt set the sync managers to the correct
            // length for you...
            const sm_assigns = try sii.readSMPDOAssigns(
                port,
                station_address,
                recv_timeout_us,
                eeprom_timeout_us,
            );

            if (maybe_sii_sms) |*sii_sms| {
                for (sm_assigns.data.slice()) |sm_assign| {
                    sii_sms.slice()[sm_assign.sm_idx].length = sm_assign.pdo_byte_length;
                }
                sms = sii.escSMsFromSIISMs(sii_sms.slice());
            }
        },
    }
    // write SM configuration to subdevice
    try commands.fpwrPackWkc(
        port,
        sms,
        .{
            .station_address = station_address,
            .offset = @intFromEnum(esc.RegisterMap.SM0),
        },
        recv_timeout_us,
        1,
    );

    // TODO: topology
    // TODO: physical type
    // TODO: active ports

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
    eeprom_timeout_us: u32,
    fmmu_inputs_start_addr: u32,
    fmmu_outputs_start_addr: u32,
) !void {

    // if CoE is supported, the subdevice PDOs can be mapped using information
    // from CoE. otherwise it can be obtained from the SII.
    // Ref: IEC 61158-5-12:2019 6.1.1.1

    // TODO: does it say somewhere that if CoE supported the PDOs MUST be in the CoE?
    const station_address = self.prior_info.station_address;

    try self.doStartupParameters(port, .PS, recv_timeout_us);

    switch (self.prior_info.auto_config) {
        .none => {},
        .sii => {
            // the entire SM configuration was already written from the SII as part of the IP transition.
            // we do not need to modify it here.

            var min_fmmu_required: u8 = 0;
            if (self.prior_info.inputs_bit_length > 0) min_fmmu_required += 1;
            if (self.prior_info.outputs_bit_length > 0) min_fmmu_required += 1;

            const fmmus = try sii.readFMMUCatagory(
                port,
                station_address,
                recv_timeout_us,
                eeprom_timeout_us,
            );
            if (fmmus.len < min_fmmu_required) return error.NotEnoughFMMUs;

            const sm_assigns = try sii.readSMPDOAssigns(
                port,
                station_address,
                recv_timeout_us,
                eeprom_timeout_us,
            );

            const totals = sm_assigns.totalBitLengths();

            if (totals.inputs_bit_length != self.prior_info.inputs_bit_length) {
                std.log.err(
                    "station addr: 0x{x}, expected inputs bit length: {}, got {}",
                    .{ station_address, self.prior_info.inputs_bit_length, totals.inputs_bit_length },
                );
                return error.InvalidInputsBitLength;
            }
            if (totals.outputs_bit_length != self.prior_info.outputs_bit_length) {
                std.log.err(
                    "station addr: 0x{x}, expected outputs bit length: {}, got {}",
                    .{ station_address, self.prior_info.outputs_bit_length, totals.outputs_bit_length },
                );
                return error.InvalidOutputsBitLength;
            }
            std.log.info("station addr: 0x{x}, inputs_bit_length: {}", .{ station_address, totals.inputs_bit_length });
            std.log.info("station addr: 0x{x}, outputs_bit_length: {}", .{ station_address, totals.outputs_bit_length });

            const fmmu_config = try sii.FMMUConfiguration.initFromSMPDOAssigns(
                sm_assigns,
                .{ .start_addr = fmmu_inputs_start_addr, .bit_length = totals.inputs_bit_length },
                .{ .start_addr = fmmu_outputs_start_addr, .bit_length = totals.outputs_bit_length },
            );
            std.log.info("station addr: 0x{x}, n_FMMU: {}, FMMU config: {any}", .{ station_address, fmmu_config.data.slice().len, fmmu_config.data.slice() });

            // TODO: Sort FMMUs according to order defined in SII
            if (fmmu_config.data.slice().len > fmmus.len) return error.NotEnoughFMMUs;

            // write fmmu configuration
            try commands.fpwrPackWkc(
                port,
                fmmu_config.dumpFMMURegister(),
                .{ .station_address = station_address, .offset = @intFromEnum(esc.RegisterMap.FMMU0) },
                recv_timeout_us,
                1,
            );
        },
    }

    // TODO: configure pdos / sync managers from CoE
    // TODO: configure PDOs from SoE
    // TODO: configure SII using information from CoE

}

pub fn transitionSO(
    self: *SubDevice,
    port: *nic.Port,
    recv_timeout_us: u32,
) !void {
    try self.doStartupParameters(port, .SO, recv_timeout_us);
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
    const this_coe = self.runtime_info.coe orelse return error.CoENotSupported;
    if (complete_access and !this_coe.supports_complete_access) return error.CoECompleteAccessNotSupported;

    return try coe.sdoWrite(
        port,
        self.prior_info.station_address,
        index,
        subindex,
        complete_access,
        buf,
        recv_timeout_us,
        mbx_timeout_us,
        self.runtime_info.coe.?.cnt.nextCnt(),
        this_coe.config,
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
    const this_coe = self.runtime_info.coe orelse return error.CoENotSupported;
    if (complete_access and !this_coe.supports_complete_access) return error.CoECompleteAccessNotSupported;

    return try coe.sdoRead(
        port,
        self.prior_info.station_address,
        index,
        subindex,
        complete_access,
        out,
        recv_timeout_us,
        mbx_timeout_us,
        self.runtime_info.coe.?.cnt.nextCnt(),
        this_coe.config,
        null,
    );
}

test {
    std.testing.refAllDecls(@This());
}
