//! SubDevice Information Interface (SII)
//!
//! Address is word (two-byte) address.

// TODO: refactor for less repetition
// TODO: Reduce memory usage of the bounded arrays in this module.

const std = @import("std");
const Timer = std.time.Timer;
const ns_per_us = std.time.ns_per_us;
const assert = std.debug.assert;

const nic = @import("nic.zig");
const wire = @import("wire.zig");
const esc = @import("esc.zig");
const commands = @import("commands.zig");

pub const ParameterMap = enum(u16) {
    PDI_control = 0x0000,
    PDI_configuration = 0x0001,
    sync_impulse_length_10ns = 0x0002,
    PDI_configuration2 = 0x0003,
    configured_station_alias = 0x0004,
    // reserved = 0x0005,
    checksum_0_to_6 = 0x0007,
    vendor_id = 0x0008,
    product_code = 0x000A,
    revision_number = 0x000C,
    serial_number = 0x000E,
    // reserved = 0x00010,
    bootstrap_recv_mbx_offset = 0x0014,
    bootstrap_recv_mbx_size = 0x0015,
    bootstrap_send_mbx_offset = 0x0016,
    bootstrap_send_mbx_size = 0x0017,
    std_recv_mbx_offset = 0x0018,
    std_recv_mbx_size = 0x0019,
    std_send_mbx_offset = 0x001A,
    std_send_mbx_size = 0x001B,
    mbx_protocol = 0x001C,
    // reserved = 0x001D,
    size = 0x003E,
    version = 0x003F,
    first_catagory_header = 0x0040,
};

/// Supported Mailbox Protocols
///
/// Ref: IEC 61158-6-12:2019 5.4 Table 18
pub const MailboxProtocolSupported = packed struct(u16) {
    AoE: bool,
    EoE: bool,
    CoE: bool,
    FoE: bool,
    SoE: bool,
    VoE: bool,
    reserved: u10 = 0,
};

pub const SubDeviceInfo = packed struct {
    PDI_control: u16,
    PDI_configuration: u16,
    sync_inpulse_length_10ns: u16,
    PDI_configuation2: u16,
    configured_station_alias: u16,
    reserved: u32 = 0,
    checksum: u16,
    vendor_id: u32,
    product_code: u32,
    revision_number: u32,
    serial_number: u32,
    reserved2: u64 = 0,
    bootstrap_recv_mbx_offset: u16,
    bootstrap_recv_mbx_size: u16,
    bootstrap_send_mbx_offset: u16,
    bootstrap_send_mbx_size: u16,
    std_recv_mbx_offset: u16,
    std_recv_mbx_size: u16,
    std_send_mbx_offset: u16,
    std_send_mbx_size: u16,
    mbx_protocol: MailboxProtocolSupported,
    reserved3: u528 = 0,
    /// size of EEPROM in kbit + 1, kbit = 1024 bits, 0 = 1 kbit.
    size: u16,
    version: u16,
};

pub const SubDeviceInfoCompact = packed struct {
    PDI_control: u16,
    PDI_configuration: u16,
    sync_inpulse_length_10ns: u16,
    PDI_configuation2: u16,
    configured_station_alias: u16,
    reserved: u32 = 0,
    checksum: u16,
    vendor_id: u32,
    product_code: u32,
    revision_number: u32,
    serial_number: u32,
    reserved2: u64 = 0,
    bootstrap_recv_mbx_offset: u16,
    bootstrap_recv_mbx_size: u16,
    bootstrap_send_mbx_offset: u16,
    bootstrap_send_mbx_size: u16,
    std_recv_mbx_offset: u16,
    std_recv_mbx_size: u16,
    std_send_mbx_offset: u16,
    std_send_mbx_size: u16,
    mbx_protocol: MailboxProtocolSupported,
};

pub const SubDeviceIdentity = packed struct {
    vendor_id: u32,
    product_code: u32,
    revision_number: u32,
};

/// SII Catagory Types
///
/// Ref: IEC 61158-6-12:2019 5.4 Table 19
pub const CatagoryType = enum(u15) {
    NOP = 0,
    strings = 10,
    data_types = 20,
    general = 30,
    FMMU = 40,
    sync_manager = 41,
    TXPDO = 50,
    RXPDO = 51,
    DC = 60,
    // end of SII is 0xffffffffffff...
    end_of_file = 0b111_1111_1111_1111,
    _,
};

pub const CatagoryHeader = packed struct {
    catagory_type: CatagoryType,
    vendor_specific: u1,
    word_size: u16,
};

/// SII Catagory String
///
/// Ref: IEC 61158-6-12:2019 5.4 Table 20
pub const CatagoryString = packed struct {
    n_strings: u8,
    // after this there is alternating
    // str_len: u8
    // str: [str_len]u8
    // it is of type VISIBLESTRING
    // TODO: unsure if null-terminated and encoding
    // string index of 0 is empty string
    // first string has index 1
};

/// CoE Details
///
/// Ref: IEC 61158-6-12:2019 5.4 Table 21
pub const CoEDetails = packed struct(u8) {
    enable_SDO: bool,
    enable_SDO_info: bool,
    enable_PDO_assign: bool,
    enable_PDO_configuration: bool,
    enable_upload_at_startup: bool,
    enable_SDO_complete_access: bool,
    reserved: u2 = 0,
};

/// FoE Details
///
/// Ref: IEC 61158-6-12:2019 5.4 Table 21
pub const FoEDetails = packed struct(u8) {
    enable_foe: bool,
    reserved: u7 = 0,
};

/// EoE Details
///
/// Ref: IEC 61158-6-12:2019 5.4 Table 21
pub const EoEDetails = packed struct(u8) {
    enable_eoe: bool,
    reserved: u7 = 0,
};

/// Flags
///
/// Ref: IEC 61158-6-12:2019 5.4 Table 21
pub const Flags = packed struct(u8) {
    enable_SAFEOP: bool,
    enable_not_LRW: bool,
    mailbox_data_link_layer: bool,
    /// ID selector mirrored in AL status code
    identity_AL_status_code: bool,
    /// ID selector value mirrored in memory address in parameter
    /// physical memory address
    identity_physical_memory: bool,
    reserved: u3 = 0,
};

/// SII Catagory General
///
/// Ref: IEC 61158-6-12:2019 5.4 Table 21
pub const CatagoryGeneral = packed struct {
    /// group information (vendor-specific), index to STRINGS
    group_idx: u8,
    /// image name (vendor specific), index to STRINGS
    image_idx: u8,
    /// order idx (vendor specific), index to STRINGS
    order_idx: u8,
    /// device name information (vendor specific), index to STRINGS
    name_idx: u8,
    reserved: u8 = 0,
    coe_details: CoEDetails,
    foe_details: FoEDetails,
    eoe_details: EoEDetails,
    /// reserved
    soe_details: u8 = 0,
    /// reserved
    ds402_channels: u8 = 0,
    /// reserved
    sysman_class: u8 = 0,
    flags: Flags,
    /// if flags.identity_physical_memory, this contains the ESC memory
    /// address where the ID switch is mirrored.
    physical_memory_address: u16,
};

/// FMMU information from the SII
///
/// Ref: IEC 61158-6-12:2019 5.4 Table 23
pub const FMMUFunction = enum(u8) {
    not_used = 0x00,
    output = 0x01,
    input = 0x02,
    syncm_status = 0x03,
    not_used2 = 0xff,
    _,
};

/// Catagory FMMU
///
/// Contains a minimum of 2 FMMUs.
///
/// Ref: IEC 61158-6-12:2019 5.4 Table 23
pub const CatagoryFMMU = packed struct(u16) {
    FMMU0: FMMUFunction,
    FMMU1: FMMUFunction,
};

pub const EnableSyncMangager = packed struct(u8) {
    enable: bool,
    /// info for config tool, this syncM has fixed content
    fixed_content: bool,
    /// true when no hardware resource used
    virtual: bool,
    /// syncM should only be enabled in OP state
    OP_only: bool,
    reserved: u4 = 0,
};

pub const SyncMType = enum(u8) {
    not_used_or_unknown = 0x00,
    mailbox_out = 0x01,
    mailbox_in = 0x02,
    process_data_outputs = 0x03,
    process_data_inputs = 0x04,
    _,
};

/// SyncM Element
///
/// Ref: IEC 61158-6-12:2019 5.4 Table 24
pub const SyncM = packed struct(u64) {
    physical_start_address: u16,
    length: u16,

    /// control register
    control: esc.SyncManagerControlRegister,
    status: esc.SyncManagerActivateRegister,
    enable_sync_manager: EnableSyncMangager,
    syncM_type: SyncMType,
};

pub fn escSMFromSIISM(sii_sm: SyncM) esc.SyncManagerAttributes {
    return esc.SyncManagerAttributes{
        .physical_start_address = sii_sm.physical_start_address,
        .length = sii_sm.length,
        .control = sii_sm.control,
        .status = @bitCast(@as(u8, 0)),
        .activate = .{
            .channel_enable = sii_sm.enable_sync_manager.enable,
            .repeat = false,
            .DC_event_0_bus_access = false,
            .DC_event_0_local_access = false,
        },
        .channel_enable_PDI = false,
        .repeat_ack = false,
    };
}

// please don't make fun of me for this, packed structs cannot currently contain arrays.
pub fn escSMsFromSIISMs(sii_sms: []const SyncM) esc.SMRegister {
    var res = std.mem.zeroes(esc.SMRegister);

    if (sii_sms.len > 0) {
        res.SM0 = escSMFromSIISM(sii_sms[0]);
    }
    if (sii_sms.len > 1) {
        res.SM1 = escSMFromSIISM(sii_sms[1]);
    }
    if (sii_sms.len > 2) {
        res.SM2 = escSMFromSIISM(sii_sms[2]);
    }
    if (sii_sms.len > 3) {
        res.SM3 = escSMFromSIISM(sii_sms[3]);
    }
    if (sii_sms.len > 4) {
        res.SM4 = escSMFromSIISM(sii_sms[4]);
    }
    if (sii_sms.len > 5) {
        res.SM5 = escSMFromSIISM(sii_sms[5]);
    }
    if (sii_sms.len > 6) {
        res.SM6 = escSMFromSIISM(sii_sms[6]);
    }
    if (sii_sms.len > 7) {
        res.SM7 = escSMFromSIISM(sii_sms[7]);
    }
    if (sii_sms.len > 8) {
        res.SM8 = escSMFromSIISM(sii_sms[8]);
    }
    if (sii_sms.len > 9) {
        res.SM9 = escSMFromSIISM(sii_sms[9]);
    }
    if (sii_sms.len > 10) {
        res.SM10 = escSMFromSIISM(sii_sms[10]);
    }
    if (sii_sms.len > 11) {
        res.SM11 = escSMFromSIISM(sii_sms[11]);
    }
    if (sii_sms.len > 12) {
        res.SM12 = escSMFromSIISM(sii_sms[12]);
    }
    if (sii_sms.len > 13) {
        res.SM13 = escSMFromSIISM(sii_sms[13]);
    }
    if (sii_sms.len > 14) {
        res.SM14 = escSMFromSIISM(sii_sms[14]);
    }
    if (sii_sms.len > 15) {
        res.SM15 = escSMFromSIISM(sii_sms[15]);
    }
    if (sii_sms.len > 16) {
        res.SM16 = escSMFromSIISM(sii_sms[16]);
    }
    if (sii_sms.len > 17) {
        res.SM17 = escSMFromSIISM(sii_sms[17]);
    }
    if (sii_sms.len > 18) {
        res.SM18 = escSMFromSIISM(sii_sms[18]);
    }
    if (sii_sms.len > 19) {
        res.SM19 = escSMFromSIISM(sii_sms[19]);
    }
    if (sii_sms.len > 20) {
        res.SM20 = escSMFromSIISM(sii_sms[20]);
    }
    if (sii_sms.len > 21) {
        res.SM21 = escSMFromSIISM(sii_sms[21]);
    }
    if (sii_sms.len > 22) {
        res.SM22 = escSMFromSIISM(sii_sms[22]);
    }
    if (sii_sms.len > 23) {
        res.SM23 = escSMFromSIISM(sii_sms[23]);
    }
    if (sii_sms.len > 24) {
        res.SM24 = escSMFromSIISM(sii_sms[24]);
    }
    if (sii_sms.len > 25) {
        res.SM25 = escSMFromSIISM(sii_sms[25]);
    }
    if (sii_sms.len > 26) {
        res.SM26 = escSMFromSIISM(sii_sms[26]);
    }
    if (sii_sms.len > 27) {
        res.SM27 = escSMFromSIISM(sii_sms[27]);
    }
    if (sii_sms.len > 28) {
        res.SM28 = escSMFromSIISM(sii_sms[28]);
    }
    if (sii_sms.len > 29) {
        res.SM29 = escSMFromSIISM(sii_sms[29]);
    }
    if (sii_sms.len > 30) {
        res.SM30 = escSMFromSIISM(sii_sms[30]);
    }
    if (sii_sms.len > 31) {
        res.SM31 = escSMFromSIISM(sii_sms[31]);
    }

    return res;
}

// pub fn countPDOs(
//     port: *nic.Port,
//     station_address: u16,
//     recv_timeout_us: u32,
//     eeprom_timeout_us: u32,
// ) void {}

pub const SIIString = std.BoundedArray(u8, 255);

pub fn readSIIString(
    port: *nic.Port,
    station_address: u16,
    index: u8,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
) !?SIIString {
    if (index == 0) {
        return null;
    }

    const catagory_res = try findCatagoryFP(
        port,
        station_address,
        CatagoryType.strings,
        recv_timeout_us,
        eeprom_timeout_us,
    );

    if (catagory_res) |catagory| {
        var stream = SIIStream.init(
            port,
            station_address,
            catagory.word_address,
            recv_timeout_us,
            eeprom_timeout_us,
        );
        var reader = stream.reader();

        const n_strings: u8 = try reader.readByte();

        if (n_strings < index) {
            return null;
        }

        var string_buf: [255]u8 = undefined;
        var str_len: u8 = undefined;
        for (0..index) |_| {
            str_len = try reader.readByte();
            try reader.readNoEof(string_buf[0..str_len]);
        } else {
            var arr = SIIString{};
            try arr.appendSlice(string_buf[0..str_len]);
            return arr;
        }
        unreachable;
    } else {
        return null;
    }
}

/// There can only be a maxiumum of 16 FMMUs.
///
/// Ref: IEC 61158-4-12:2019 6.6.1
pub const max_fmmu = 16;
pub const FMMUCatagory = std.BoundedArray(FMMUFunction, max_fmmu);

pub fn readFMMUCatagory(
    port: *nic.Port,
    station_address: u16,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
) !FMMUCatagory {
    var res = FMMUCatagory{};

    const catagory = try findCatagoryFP(
        port,
        station_address,
        .FMMU,
        recv_timeout_us,
        eeprom_timeout_us,
    ) orelse return res;

    const n_fmmu: u17 = std.math.divExact(
        u17,
        catagory.byte_length,
        @divExact(@bitSizeOf(FMMUFunction), 8),
    ) catch return error.InvalidSII;
    if (n_fmmu == 0) {
        assert(res.len == 0);
        return res;
    }
    if (n_fmmu > max_fmmu) {
        return error.InvalidSII;
    }
    var stream = SIIStream.init(
        port,
        station_address,
        catagory.word_address,
        recv_timeout_us,
        eeprom_timeout_us,
    );
    var limited_reader = std.io.limitedReader(stream.reader(), catagory.byte_length);
    const reader = limited_reader.reader();

    for (0..n_fmmu) |_| {
        res.append(try wire.packFromECatReader(FMMUFunction, reader)) catch |err| switch (err) {
            error.Overflow => return error.InvalidSII,
        };
    }
    return res;
}

/// There can only be a maximum of 32 sync managers.
///
/// Ref: IEC 61158-6-12:2019 6.7.2
pub const max_sm = 32;
pub const SMCatagory = std.BoundedArray(SyncM, max_sm);

pub fn readSMCatagory(
    port: *nic.Port,
    station_address: u16,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
) !?SMCatagory {
    const catagory = try findCatagoryFP(
        port,
        station_address,
        .sync_manager,
        recv_timeout_us,
        eeprom_timeout_us,
    ) orelse return null;
    const n_sm: u17 = std.math.divExact(u17, catagory.byte_length, @divExact(@bitSizeOf(SyncM), 8)) catch return error.InvalidSII;
    if (n_sm == 0) {
        return null;
    }
    if (n_sm > max_sm) {
        return error.InvalidSII;
    }
    var stream = SIIStream.init(
        port,
        station_address,
        catagory.word_address,
        recv_timeout_us,
        eeprom_timeout_us,
    );
    var limited_reader = std.io.limitedReader(stream.reader(), catagory.byte_length);
    const reader = limited_reader.reader();
    var res = SMCatagory{};
    for (0..n_sm) |_| {
        res.append(try wire.packFromECatReader(SyncM, reader)) catch |err| switch (err) {
            error.Overflow => return error.InvalidSII,
        };
    }
    return res;
}

pub fn readGeneralCatagory(port: *nic.Port, station_address: u16, recv_timeout_us: u32, eeprom_timeout_us: u32) !?CatagoryGeneral {
    const catagory = try findCatagoryFP(
        port,
        station_address,
        .general,
        recv_timeout_us,
        eeprom_timeout_us,
    ) orelse return null;

    if (catagory.byte_length < @divExact(@bitSizeOf(CatagoryGeneral), 8)) {
        std.log.err(
            "SubDevice station addr: 0x{x} has invalid eeprom sii general length: {}. Expected >= {}",
            .{ station_address, catagory.byte_length, @divExact(@bitSizeOf(CatagoryGeneral), 8) },
        );
        return error.InvalidSubDeviceEEPROM;
    }

    const general = try readSIIFP_ps(
        port,
        CatagoryGeneral,
        station_address,
        catagory.word_address,
        recv_timeout_us,
        eeprom_timeout_us,
    );
    return general;
}

pub const PDO = struct {
    header: Header,
    entries: std.BoundedArray(
        Entry,
        max_entries,
    ),

    /// PDO Header
    ///
    /// Applies to both TXPDO and RXPDO SII catagories.
    ///
    /// Ref: IEC 61158-6-12:2019 5.4 Table 25
    pub const Header = packed struct(u64) {
        /// for RxPDO: 0x1600 to 0x17ff
        /// for TxPDO: 0x1A00 to 0x1bff
        index: u16,
        n_entries: u8,
        /// reference to sync manager
        syncM: u8,
        /// referece to DC synch
        synchronization: u8,
        /// name of object, index to STRINGS
        name_idx: u8,
        /// reserved
        flags: u16 = 0,
        // entries sequentially after this

        // Some subdevices support variable PDO assignment.
        // In this case, the SII only contains one possible
        // PDO assignment.
        //
        // Unused PDOs are typically marked by specifiying
        // the assigned syncmanager as 0xFF. There doesn't seem to be
        // any thing in the specs about this. There can only be a maximum of
        // 32 sync managers, so we will just check if the assigned
        // sync manager is even possible.
        // Use < and not <= since sync manager index starts at zero.
        pub fn isUsed(self: Header) bool {
            return !(self.syncM > max_sm);
        }
    };

    /// PDO Entry
    ///
    /// Ref: IEC 61158-6-12:2019 5.4 Table 26
    pub const Entry = packed struct(u64) {
        /// index of the entry
        index: u16,
        subindex: u8,
        /// name of the entry, index to STRINGS
        name_idx: u8,
        /// data type of the entry, index in CoE object dictionary
        data_type: u8,
        /// bit length of the entry
        bit_length: u8,
        /// reserved
        flags: u16 = 0,
    };

    pub fn bitLength(self: PDO) u32 {
        var res: u32 = 0;
        for (self.entries.slice()) |entry| {
            res += entry.bit_length;
        }
        return res;
    }

    /// The maximum number of PDO entries in a single PDOs
    ///
    /// In the CoE, this must be 254 or fewer. So we will assume that.
    /// Ref: IEC 61158-6-12:2019 5.6.7.4.7
    pub const max_entries = 254;
};

/// Each TxPDO is identified by an index from 0x1600 to 17FF. Therefore,
/// there is a maxiumum of 512 tx pdos.
///
/// Ref: IEC 61158-6-12:2019 5.4 table 25
pub const max_txpdos = 512;
pub const max_rxpdos = 512;
comptime {
    assert(max_txpdos == 0x17FF - 0x1600 + 1);
    assert(max_rxpdos == 0x1BFF - 0x1A00 + 1);
}

pub const PDOs = std.BoundedArray(PDO, max_txpdos);

/// Calculate the bit length of a given set of PDOs ignoring un-used PDOs.
pub fn pdoBitLength(pdos: []const PDO) u32 {
    var res: u32 = 0;
    for (pdos) |pdo| {
        if (pdo.header.syncM < max_sm) {
            for (pdo.entries.slice()) |entry| {
                res += entry.bit_length;
            }
        }
    }
    return res;
}

pub const PDODirection = enum {
    /// TXPDO = input = transmitted by subdevice
    tx,
    /// RXPDO = output = transmitted by maindevice
    rx,
};

/// Read the full set of PDOs from the eeprom.
///
/// Warning: this uses about 1 MB of stack memory.
pub fn readPDOs(
    port: *nic.Port,
    station_address: u16,
    direction: PDODirection,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
) !?PDOs {
    const catagory = try findCatagoryFP(
        port,
        station_address,
        switch (direction) {
            .tx => .TXPDO,
            .rx => .RXPDO,
        },
        recv_timeout_us,
        eeprom_timeout_us,
    ) orelse return null;

    // entries are 8 bytes, pdo header is 8 bytes, so
    // this should be a multiple of eight.
    if (catagory.byte_length % 8 != 0) return error.InvalidEEPROM;

    var stream = SIIStream.init(
        port,
        station_address,
        catagory.word_address,
        recv_timeout_us,
        eeprom_timeout_us,
    );
    var limited_reader = std.io.limitedReader(stream.reader(), catagory.byte_length);
    const reader = limited_reader.reader();

    var pdos = std.BoundedArray(PDO, max_txpdos){};

    const State = enum {
        entries,
        pdo_header,
        emit_pdo,
    };
    var entries = std.BoundedArray(PDO.Entry, PDO.max_entries){};
    var pdo_header: PDO.Header = undefined;
    var entries_remaining: u8 = 0;
    state: switch (State.pdo_header) {
        .pdo_header => {
            entries.clear();
            pdo_header = wire.packFromECatReader(PDO.Header, reader) catch |err| switch (err) {
                error.EndOfStream => return pdos,
                error.LinkError => return error.LinkError,
                error.Timeout => return error.Timeout,
            };
            if (pdo_header.n_entries > PDO.max_entries) return error.InvalidEEPROM;
            entries_remaining = pdo_header.n_entries;
            continue :state .entries;
        },
        .entries => {
            if (entries_remaining == 0) continue :state .emit_pdo;
            const entry = try wire.packFromECatReader(PDO.Entry, reader);
            try entries.append(entry);
            entries_remaining -= 1;
            continue :state .entries;
        },
        .emit_pdo => {
            try pdos.append(.{ .header = pdo_header, .entries = entries });
            continue :state .pdo_header;
        },
    }
}

pub const FindCatagoryResult = struct {
    /// word address of the data portion (not including header)
    word_address: u16,
    /// length of the data portion in bytes
    byte_length: u17,
};

/// find the word address of a catagory in the eeprom, uses station addressing.
///
/// Returns null if catagory is not found.
pub fn findCatagoryFP(
    port: *nic.Port,
    station_address: u16,
    catagory: CatagoryType,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
) !?FindCatagoryResult {

    // there shouldn't be more than 1000 catagories..right??
    const word_address: u16 = @intFromEnum(ParameterMap.first_catagory_header);
    var stream = SIIStream.init(
        port,
        station_address,
        word_address,
        recv_timeout_us,
        eeprom_timeout_us,
    );

    const reader = stream.reader();
    for (0..1000) |_| {
        const catagory_header = try wire.packFromECatReader(CatagoryHeader, reader.any());

        if (catagory_header.catagory_type == catagory) {
            // + 2 for catagory header, byte length = 2 * word length
            // return .{ .word_address = word_address + 2, .byte_length = word_address << 1 };
            return .{ .word_address = stream.eeprom_address, .byte_length = catagory_header.word_size << 1 };
        } else if (catagory_header.catagory_type == .end_of_file) {
            return null;
        } else {
            //word_address += catagory_header.word_size + 2; // + 2 for catagory header
            stream.seekByWord(catagory_header.word_size);
            continue;
        }
        unreachable;
    } else {
        return null;
    }
}

/// read a packed struct from SII, using station addressing
pub fn readSIIFP_ps(
    port: *nic.Port,
    comptime T: type,
    station_address: u16,
    eeprom_address: u16,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
) !T {
    var bytes: [@divExact(@bitSizeOf(T), 8)]u8 = undefined;
    var stream = SIIStream.init(
        port,
        station_address,
        eeprom_address,
        recv_timeout_us,
        eeprom_timeout_us,
    );
    var reader = stream.reader();
    try reader.readNoEof(&bytes);
    return wire.packFromECat(T, bytes);
}

pub const SIIStream = struct {
    port: *nic.Port,
    station_address: u16,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
    eeprom_address: u16, // WORD (2-byte) address

    last_four_bytes: [4]u8 = .{ 0, 0, 0, 0 },
    remainder: u8 = 0,

    pub fn init(
        port: *nic.Port,
        station_address: u16,
        eeprom_address: u16,
        recv_timeout_us: u32,
        eeprom_timeout_us: u32,
    ) SIIStream {
        return SIIStream{
            .port = port,
            .station_address = station_address,
            .eeprom_address = eeprom_address,
            .recv_timeout_us = recv_timeout_us,
            .eeprom_timeout_us = eeprom_timeout_us,
        };
    }

    pub const ReadError = error{
        Timeout,
        LinkError,
    };

    // pub fn reader(self: *SIIStream) std.io.AnyReader {
    //     return .{ .context = self, .readFn = read };
    // }

    pub fn reader(self: *SIIStream) std.io.GenericReader(*@This(), ReadError, read) {
        return .{ .context = self };
    }

    fn read(self: *SIIStream, buf: []u8) ReadError!usize {
        if (self.remainder == 0) {
            self.last_four_bytes = try readSII4ByteFP(
                self.port,
                self.station_address,
                self.eeprom_address, // eeprom address is WORD address
                self.recv_timeout_us,
                self.eeprom_timeout_us,
            );
            self.eeprom_address += 2;

            self.remainder = 4;
        }

        var fbs = std.io.fixedBufferStream(buf);
        var writer = fbs.writer();

        while (self.remainder != 0) {
            writer.writeByte(self.last_four_bytes[4 - self.remainder]) catch return fbs.getWritten().len;
            self.remainder -= 1;
        } else {
            return fbs.getWritten().len;
        }
        unreachable;
    }

    pub fn seekByWord(self: *SIIStream, amt: u16) void {
        self.eeprom_address += amt;
        self.remainder = 0; // next call to read will always read eeprom
    }
};

pub fn seek(address: u16, amount: u15) u16 {
    return address +% amount;
}

test {
    try std.testing.expectEqual(@as(u16, 3), seek(0, 3));
}

pub const ReadSIIError = error{
    Timeout,
    LinkError,
};

/// read 4 bytes from SII, using station addressing
pub fn readSII4ByteFP(
    port: *nic.Port,
    station_address: u16,
    eeprom_address: u16,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
) ReadSIIError![4]u8 {

    // set eeprom access to main device
    commands.fpwrPackWkc(
        port,
        esc.SIIAccessRegisterCompact{
            .owner = .ethercat_DL,
            .lock = false,
        },
        .{
            .station_address = station_address,
            .offset = @intFromEnum(esc.RegisterMap.SII_access),
        },
        recv_timeout_us,
        1,
    ) catch |err| switch (err) {
        error.TransactionContention => return error.Timeout,
        error.RecvTimeout => return error.Timeout,
        error.CurruptedFrame => return error.Timeout,
        error.Wkc => return error.Timeout,
        error.LinkError => return error.LinkError,
    };

    // ensure there is a rising edge in the read command by first sending zeros
    commands.fpwrPackWkc(
        port,
        @as(u16, @bitCast(wire.zerosFromPack(esc.SIIControlStatusRegister))),
        .{
            .station_address = station_address,
            .offset = @intFromEnum(esc.RegisterMap.SII_control_status),
        },
        recv_timeout_us,
        1,
    ) catch |err| switch (err) {
        error.LinkError => return error.LinkError,
        error.TransactionContention => return error.Timeout,
        error.CurruptedFrame => return error.Timeout,
        error.RecvTimeout => return error.Timeout,
        error.Wkc => return error.Timeout,
    };
    // send read command
    commands.fpwrPackWkc(
        port,
        esc.SIIControlStatusAddressRegister{
            .write_access = false,
            .EEPROM_emulation = false,
            .read_size = .four_bytes,
            .address_algorithm = .one_byte_address,
            .read_operation = true, // <-- cmd
            .write_operation = false,
            .reload_operation = false,
            .checksum_error = false,
            .device_info_error = false,
            .command_error = false,
            .write_error = false,
            .busy = false,
            .sii_address = eeprom_address,
        },
        .{
            .station_address = station_address,
            .offset = @intFromEnum(esc.RegisterMap.SII_control_status),
        },
        recv_timeout_us,
        1,
    ) catch |err| switch (err) {
        error.LinkError => return error.LinkError,
        error.TransactionContention => return error.Timeout,
        error.CurruptedFrame => return error.Timeout,
        error.RecvTimeout => return error.Timeout,
        error.Wkc => return error.Timeout,
    };

    var timer = Timer.start() catch |err| switch (err) {
        error.TimerUnsupported => unreachable,
    };
    // wait for eeprom to be not busy
    while (timer.read() < eeprom_timeout_us * ns_per_us) {
        const sii_status = commands.fprdPackWkc(
            port,
            esc.SIIControlStatusRegister,
            .{
                .station_address = station_address,
                .offset = @intFromEnum(
                    esc.RegisterMap.SII_control_status,
                ),
            },
            recv_timeout_us,
            1,
        ) catch |err| switch (err) {
            error.LinkError => return error.LinkError,
            error.TransactionContention => return error.Timeout,
            error.CurruptedFrame => return error.Timeout,
            error.RecvTimeout => return error.Timeout,
            error.Wkc => return error.Timeout,
        };

        if (sii_status.busy) {
            continue;
        } else {
            // check for eeprom nack
            if (sii_status.command_error) {
                // TODO: this should never happen?
                continue;
            }
            break;
        }
    } else {
        return error.Timeout;
    }

    // attempt read 3 times
    var data = [4]u8{ 0, 0, 0, 0 };
    commands.fprdWkc(
        port,
        .{
            .station_address = station_address,
            .offset = @intFromEnum(
                esc.RegisterMap.SII_data,
            ),
        },
        &data,
        recv_timeout_us,
        1,
    ) catch |err| switch (err) {
        error.LinkError => return error.LinkError,
        error.TransactionContention => return error.Timeout,
        // error.FrameSerializationFailure => unreachable,
        error.CurruptedFrame => return error.Timeout,
        error.RecvTimeout => return error.Timeout,
        error.Wkc => return error.Timeout,
    };
    return data;
}

pub const SMPDOBitLength = struct {
    /// index of this sync manager
    sm_idx: u8,
    /// start address in esc memory
    start_addr: u32,
    pdo_byte_length: u16,
    /// total bit length of PDOs assigned to this sync manager.
    pdo_bit_length: u16,
    direction: PDODirection,
};

pub const SMPDOBitLengths = struct {
    pdo_bit_lengths: std.BoundedArray(SMPDOBitLength, max_sm) = .{},

    pub const Totals = struct {
        inputs_bit_length: u32 = 0,
        outputs_bit_length: u32 = 0,
    };
    pub fn totalBitLengths(self: *const SMPDOBitLengths) Totals {
        var res = Totals{};
        for (self.pdo_bit_lengths.slice()) |pdo_bit_length| {
            switch (pdo_bit_length.direction) {
                .tx => {
                    res.inputs_bit_length += pdo_bit_length.pdo_bit_length;
                },
                .rx => {
                    res.outputs_bit_length += pdo_bit_length.pdo_bit_length;
                },
            }
        }
        return res;
    }

    pub fn addPDOBitsToSM(self: *SMPDOBitLengths, bit_length: u8, sm_idx: u8, direction: PDODirection) !void {
        assert(sm_idx < max_sm);
        for ((&self.pdo_bit_lengths).slice()) |*pdo_bit_length| {
            if (pdo_bit_length.sm_idx == sm_idx) {
                if (direction != pdo_bit_length.direction) {
                    return error.WrongDirection;
                }
                pdo_bit_length.pdo_bit_length += bit_length;
                // TODO: this is inefficient to re-calcuate every time but I don't care
                pdo_bit_length.pdo_byte_length = (pdo_bit_length.pdo_bit_length + 7) / 8;
                return;
            }
        } else {
            return error.SyncManagerNotFound;
        }
    }
    pub fn addSyncManager(self: *SMPDOBitLengths, sm_config: SyncM, sm_idx: u8) !void {
        assert(sm_idx < max_sm);
        assert(sm_config.syncM_type == .process_data_inputs or sm_config.syncM_type == .process_data_outputs);
        assert(sm_config.physical_start_address != 0);
        try self.pdo_bit_lengths.append(SMPDOBitLength{
            .pdo_bit_length = 0,
            .pdo_byte_length = 0,
            .sm_idx = sm_idx,
            .start_addr = sm_config.physical_start_address,
            .direction = switch (sm_config.syncM_type) {
                .process_data_inputs => .tx,
                .process_data_outputs => .rx,
                else => unreachable,
            },
        });
    }

    fn lessThan(context: void, a: SMPDOBitLength, b: SMPDOBitLength) bool {
        _ = context;
        return a.start_addr < b.start_addr;
    }

    pub fn sortAndVerifyNonOverlapping(self: *SMPDOBitLengths) !void {
        if (self.pdo_bit_lengths.len <= 1) return;

        std.sort.insertion(SMPDOBitLength, self.pdo_bit_lengths.slice(), {}, SMPDOBitLengths.lessThan);
        assert(std.sort.isSorted(SMPDOBitLength, self.pdo_bit_lengths.slice(), {}, SMPDOBitLengths.lessThan));
        for (1..self.pdo_bit_lengths.len) |i| {
            const this_sm = self.pdo_bit_lengths.slice()[i];
            const last_sm = self.pdo_bit_lengths.slice()[i - 1];
            if (last_sm.start_addr + last_sm.pdo_byte_length > this_sm.start_addr or
                last_sm.start_addr == this_sm.start_addr)
            {
                std.log.warn("overlapping sync managers: {}, {}", .{ this_sm, last_sm });
                return error.OverlappingSM;
            }
        }
    }
};

test "sort and verfiy non overlapping SMPDOBitLengths" {
    var pdo_bit_lengths = SMPDOBitLengths{};
    try pdo_bit_lengths.pdo_bit_lengths.append(SMPDOBitLength{ .direction = .tx, .pdo_bit_length = 12, .pdo_byte_length = 2, .start_addr = 1000, .sm_idx = 2 });
    try pdo_bit_lengths.pdo_bit_lengths.append(SMPDOBitLength{ .direction = .tx, .pdo_bit_length = 12, .pdo_byte_length = 2, .start_addr = 998, .sm_idx = 4 });
    try pdo_bit_lengths.pdo_bit_lengths.append(SMPDOBitLength{ .direction = .tx, .pdo_bit_length = 12, .pdo_byte_length = 2, .start_addr = 1002, .sm_idx = 1 });
    try pdo_bit_lengths.sortAndVerifyNonOverlapping();

    try std.testing.expectEqual(@as(u32, 998), pdo_bit_lengths.pdo_bit_lengths.slice()[0].start_addr);
    try std.testing.expectEqual(@as(u32, 1000), pdo_bit_lengths.pdo_bit_lengths.slice()[1].start_addr);
    try std.testing.expectEqual(@as(u32, 1002), pdo_bit_lengths.pdo_bit_lengths.slice()[2].start_addr);
}

test "overlapping sync managers" {
    var pdo_bit_lengths = SMPDOBitLengths{};
    try pdo_bit_lengths.pdo_bit_lengths.append(SMPDOBitLength{ .direction = .tx, .pdo_bit_length = 12, .pdo_byte_length = 2, .start_addr = 1000, .sm_idx = 3 });
    try pdo_bit_lengths.pdo_bit_lengths.append(SMPDOBitLength{ .direction = .tx, .pdo_bit_length = 12, .pdo_byte_length = 3, .start_addr = 998, .sm_idx = 3 });
    try pdo_bit_lengths.pdo_bit_lengths.append(SMPDOBitLength{ .direction = .tx, .pdo_bit_length = 12, .pdo_byte_length = 2, .start_addr = 1002, .sm_idx = 3 });
    try std.testing.expectError(error.OverlappingSM, pdo_bit_lengths.sortAndVerifyNonOverlapping());
}

test "overlapping sync managers non unique start addr" {
    var pdo_bit_lengths = SMPDOBitLengths{};
    try pdo_bit_lengths.pdo_bit_lengths.append(SMPDOBitLength{ .direction = .tx, .pdo_bit_length = 12, .pdo_byte_length = 2, .start_addr = 1000, .sm_idx = 3 });
    try pdo_bit_lengths.pdo_bit_lengths.append(SMPDOBitLength{ .direction = .tx, .pdo_bit_length = 12, .pdo_byte_length = 2, .start_addr = 1000, .sm_idx = 3 });
    try pdo_bit_lengths.pdo_bit_lengths.append(SMPDOBitLength{ .direction = .tx, .pdo_bit_length = 12, .pdo_byte_length = 2, .start_addr = 1002, .sm_idx = 3 });
    try std.testing.expectError(error.OverlappingSM, pdo_bit_lengths.sortAndVerifyNonOverlapping());
}

pub fn readSMPDOBitLengths(
    port: *nic.Port,
    station_address: u16,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
) !SMPDOBitLengths {
    var res = SMPDOBitLengths{};
    const sm_catagory = try readSMCatagory(
        port,
        station_address,
        recv_timeout_us,
        eeprom_timeout_us,
    ) orelse return res;
    const sync_managers = sm_catagory.slice();

    for (sync_managers, 0..) |sm_config, sm_idx| {
        switch (sm_config.syncM_type) {
            .mailbox_in, .mailbox_out, .not_used_or_unknown => {},
            _ => return error.InvalidEEPROM,
            .process_data_inputs, .process_data_outputs => {
                try res.addSyncManager(sm_config, @intCast(sm_idx));
            },
        }
    }

    for ([2]CatagoryType{ .TXPDO, .RXPDO }) |catagory_type| {
        const catagory = try findCatagoryFP(
            port,
            station_address,
            catagory_type,
            recv_timeout_us,
            eeprom_timeout_us,
        ) orelse {
            std.log.info("station_addr: 0x{x}, couldnt find cat: {}, skipping", .{ station_address, catagory_type });
            continue;
        };

        // entries are 8 bytes, pdo header is 8 bytes, so
        // this should be a multiple of eight.
        if (catagory.byte_length % 8 != 0) return error.InvalidEEPROM;

        var stream = SIIStream.init(
            port,
            station_address,
            catagory.word_address,
            recv_timeout_us,
            eeprom_timeout_us,
        );
        var limited_reader = std.io.limitedReader(stream.reader(), catagory.byte_length);
        const reader = limited_reader.reader();

        var pdo_header: PDO.Header = undefined;
        var entries_remaining: u8 = 0;
        var current_sm_idx: u8 = 0;
        const State = enum { pdo_header, entries, entries_skip, end };
        state: switch (State.pdo_header) {
            .pdo_header => {
                assert(entries_remaining == 0);
                pdo_header = wire.packFromECatReader(PDO.Header, reader) catch |err| switch (err) {
                    error.EndOfStream => continue :state .end,
                    error.LinkError => return error.LinkError,
                    error.Timeout => return error.Timeout,
                };
                if (pdo_header.n_entries > PDO.max_entries) return error.InvalidEEPROM;
                current_sm_idx = pdo_header.syncM;
                entries_remaining = pdo_header.n_entries;
                if (pdo_header.isUsed()) continue :state .entries else continue :state .entries_skip;
            },
            .entries => {
                assert(pdo_header.syncM < std.math.maxInt(u8));
                assert(current_sm_idx < max_sm);
                if (entries_remaining == 0) continue :state .pdo_header;
                const entry = try wire.packFromECatReader(PDO.Entry, reader);
                entries_remaining -= 1;
                try res.addPDOBitsToSM(
                    entry.bit_length,
                    current_sm_idx,
                    switch (catagory_type) {
                        .TXPDO => .tx,
                        .RXPDO => .rx,
                        else => unreachable,
                    },
                );
                continue :state .entries;
            },
            .entries_skip => {
                if (entries_remaining == 0) continue :state .pdo_header;
                _ = try wire.packFromECatReader(PDO.Entry, reader);
                entries_remaining -= 1;
                continue :state .entries_skip;
            },
            .end => {},
        }
    }
    try res.sortAndVerifyNonOverlapping();
    return res;
}

// TODO: remove this?
/// Iterate over all the PDOs defined in the SII and report the
/// total bitlength of the inputs or the outputs (depending on direction parameter).
///
/// Uses much less stack memory than readPDOs.
pub fn readPDOBitLengths(
    port: *nic.Port,
    station_address: u16,
    direction: PDODirection,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
) !u32 {
    const catagory = try findCatagoryFP(
        port,
        station_address,
        switch (direction) {
            .tx => .TXPDO,
            .rx => .RXPDO,
        },
        recv_timeout_us,
        eeprom_timeout_us,
    ) orelse return 0;

    // entries are 8 bytes, pdo header is 8 bytes, so
    // this should be a multiple of eight.
    if (catagory.byte_length % 8 != 0) return error.InvalidEEPROM;

    var stream = SIIStream.init(
        port,
        station_address,
        catagory.word_address,
        recv_timeout_us,
        eeprom_timeout_us,
    );
    var limited_reader = std.io.limitedReader(stream.reader(), catagory.byte_length);
    const reader = limited_reader.reader();

    const State = enum {
        pdo_header,
        entries,
        entries_skip,
    };
    var pdo_header: PDO.Header = undefined;
    var entries_remaining: u8 = 0;
    var total_bit_length: u32 = 0;
    state: switch (State.pdo_header) {
        .pdo_header => {
            assert(entries_remaining == 0);
            pdo_header = wire.packFromECatReader(PDO.Header, reader) catch |err| switch (err) {
                error.EndOfStream => return total_bit_length,
                error.LinkError => return error.LinkError,
                error.Timeout => return error.Timeout,
            };
            if (pdo_header.n_entries > PDO.max_entries) return error.InvalidEEPROM;
            entries_remaining = pdo_header.n_entries;
            if (pdo_header.isUsed()) continue :state .entries else continue :state .entries_skip;
        },
        .entries => {
            if (entries_remaining == 0) continue :state .pdo_header;
            const entry = try wire.packFromECatReader(PDO.Entry, reader);
            entries_remaining -= 1;
            total_bit_length += entry.bit_length;
            continue :state .entries;
        },
        .entries_skip => {
            if (entries_remaining == 0) continue :state .pdo_header;
            _ = try wire.packFromECatReader(PDO.Entry, reader);
            entries_remaining -= 1;
            continue :state .entries_skip;
        },
    }
}

test {
    std.testing.refAllDecls(@This());
}
