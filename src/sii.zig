//! SubDevice Information Interface (SII)
//!
//! Address is word (two-byte) address.

// TODO: refactor for less repetition

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
    used_for_outputs = 0x01,
    used_for_inputs = 0x02,
    used_for_syncm_status = 0x03,
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

/// PDO Entry
///
/// Ref: IEC 61158-6-12:2019 5.4 Table 26
pub const PDOEntry = packed struct {
    /// index of the entry
    index: u16,
    subindex: u8,
    /// name of the entry, index to STRINGS
    name_idx: u8,
    /// data type of the entry, index in CoE object dictionary
    data_type: u8,
    /// bit length of the entry
    bit_len: u8,
    /// reserved
    flags: u16 = 0,
};

/// Catagory PDO
///
/// Applies to both TXPDO and RXPDO SII catagories.
///
/// Ref: IEC 61158-6-12:2019 5.4 Table 25
pub const CatagoryPDO = packed struct {
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

pub fn escSMsFromSIISMs(sii_sms: [16]?SyncM) esc.SMRegister {
    var res = std.mem.zeroes(esc.SMRegister);

    if (sii_sms[0]) |SM0| {
        res.SM0 = escSMFromSIISM(SM0);
    }
    if (sii_sms[1]) |SM1| {
        res.SM1 = escSMFromSIISM(SM1);
    }
    if (sii_sms[2]) |SM2| {
        res.SM2 = escSMFromSIISM(SM2);
    }
    if (sii_sms[3]) |SM3| {
        res.SM3 = escSMFromSIISM(SM3);
    }
    if (sii_sms[4]) |SM4| {
        res.SM4 = escSMFromSIISM(SM4);
    }
    if (sii_sms[5]) |SM5| {
        res.SM5 = escSMFromSIISM(SM5);
    }
    if (sii_sms[6]) |SM6| {
        res.SM6 = escSMFromSIISM(SM6);
    }
    if (sii_sms[7]) |SM7| {
        res.SM7 = escSMFromSIISM(SM7);
    }
    if (sii_sms[8]) |SM8| {
        res.SM8 = escSMFromSIISM(SM8);
    }
    if (sii_sms[9]) |SM9| {
        res.SM9 = escSMFromSIISM(SM9);
    }
    if (sii_sms[10]) |SM10| {
        res.SM10 = escSMFromSIISM(SM10);
    }
    if (sii_sms[11]) |SM11| {
        res.SM11 = escSMFromSIISM(SM11);
    }
    if (sii_sms[12]) |SM12| {
        res.SM12 = escSMFromSIISM(SM12);
    }
    if (sii_sms[13]) |SM13| {
        res.SM13 = escSMFromSIISM(SM13);
    }
    if (sii_sms[14]) |SM14| {
        res.SM14 = escSMFromSIISM(SM14);
    }
    if (sii_sms[15]) |SM15| {
        res.SM15 = escSMFromSIISM(SM15);
    }
    return res;
}

pub const SIIString = std.BoundedArray(u8, 255);

pub fn readSIIString(
    port: *nic.Port,
    station_address: u16,
    index: u8,
    retries: u32,
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
        retries,
        recv_timeout_us,
        eeprom_timeout_us,
    );

    if (catagory_res) |catagory| {
        var stream = SIIStream.init(
            port,
            station_address,
            catagory.word_address,
            retries,
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
            var arr = try SIIString.init(0);
            try arr.appendSlice(string_buf[0..str_len]);
            return arr;
        }
        unreachable;
    } else {
        return null;
    }
}

pub const FindCatagoryResult = struct {
    /// word address of the data portion (not including header)
    word_address: u16,
    /// length of the data portion in bytes
    byte_length: u17,
};

pub fn readFMMUCatagory(
    port: *nic.Port,
    station_address: u16,
    retries: u32,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
) !?[16]?FMMUFunction {
    const fmmu_catagory = try findCatagoryFP(
        port,
        station_address,
        .FMMU,
        retries,
        recv_timeout_us,
        eeprom_timeout_us,
    );
    if (fmmu_catagory) |catagory| {
        const n_fmmu: u17 = std.math.divExact(u17, catagory.byte_length, @divExact(@bitSizeOf(FMMUFunction), 8)) catch return error.InvalidSII;
        if (n_fmmu == 0) {
            return null;
        } else if (n_fmmu > 16) {
            return error.InvalidSII;
        }
        var stream = SIIStream.init(
            port,
            station_address,
            catagory.word_address,
            retries,
            recv_timeout_us,
            eeprom_timeout_us,
        );
        var reader = stream.reader();
        var res: [16]?FMMUFunction = [_]?FMMUFunction{null} ** 16;
        for (res[0..n_fmmu]) |*fmmu| {
            fmmu.* = @enumFromInt(try reader.readByte());
        }
        return res;
    } else {
        return null;
    }
    unreachable;
}

pub fn readSMCatagory(
    port: *nic.Port,
    station_address: u16,
    retries: u32,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
) !?[16]?SyncM {
    const sm_catagory = try findCatagoryFP(
        port,
        station_address,
        .sync_manager,
        retries,
        recv_timeout_us,
        eeprom_timeout_us,
    );

    if (sm_catagory) |catagory| {
        const n_sm: u17 = std.math.divExact(u17, catagory.byte_length, @divExact(@bitSizeOf(SyncM), 8)) catch return error.InvalidSII;
        if (n_sm == 0) {
            return null;
        } else if (n_sm > 16) {
            return error.InvalidSII;
        }
        var stream = SIIStream.init(
            port,
            station_address,
            catagory.word_address,
            retries,
            recv_timeout_us,
            eeprom_timeout_us,
        );
        var reader = stream.reader();

        var res: [16]?SyncM = [_]?SyncM{null} ** 16;
        for (res[0..n_sm]) |*sm| {
            sm.* = try wire.packFromECatReader(SyncM, &reader);
        }
        return res;
    } else {
        return null;
    }
    unreachable;
}

pub fn readGeneralCatagory(port: *nic.Port, station_address: u16, retries: u32, recv_timeout_us: u32, eeprom_timeout_us: u32) !?CatagoryGeneral {
    const gen_catagory = try findCatagoryFP(
        port,
        station_address,
        .general,
        3,
        recv_timeout_us,
        eeprom_timeout_us,
    );

    if (gen_catagory) |catagory| {
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
            retries,
            recv_timeout_us,
            eeprom_timeout_us,
        );
        return general;
    } else {
        return null;
    }
    unreachable;
}

/// find the word address of a catagory in the eeprom, uses station addressing.
///
/// Returns null if catagory is not found.
pub fn findCatagoryFP(port: *nic.Port, station_address: u16, catagory: CatagoryType, retries: u32, recv_timeout_us: u32, eeprom_timeout_us: u32) !?FindCatagoryResult {

    // there shouldn't be more than 1000 catagories..right??
    const word_address: u16 = @intFromEnum(ParameterMap.first_catagory_header);
    var stream = SIIStream.init(
        port,
        station_address,
        word_address,
        retries,
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
    retries: u32,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
) !T {
    var bytes: [@divExact(@bitSizeOf(T), 8)]u8 = undefined;
    var stream = SIIStream.init(
        port,
        station_address,
        eeprom_address,
        retries,
        recv_timeout_us,
        eeprom_timeout_us,
    );
    var reader = stream.reader();
    try reader.readNoEof(&bytes);
    return wire.packFromECat(T, bytes);
}

/// read bytes from SII into slice, uses station addressing
// pub fn readSIIString(port: *Port, station_address: u16, string_idx: u8, out: []u8, retries: u32, recv_timeout_us: u32, eeprom_timeout_us: u32) !void {
//     const str_catagory = try findCatagoryFP(
//         port,
//         station_address,
//         CatagoryType.strings,
//         retries,
//         recv_timeout_us,
//         eeprom_timeout_us,
//     );

//     var buf: [128]u8 = undefined;

//     if (str_catagory) |catagory| {
//         const res = readSII4ByteFP(
//             port,
//             station_address,
//             catagory.word_address,
//             retries,
//             recv_timeout_us,
//             eeprom_timeout_us,
//         );
//         const n_strings: u8 = res[0];

//         if (n_strings < string_idx) {
//             return error.StringIdxNotFound;
//         }

//         var eeprom_word_offset: u16 = 0;
//         var current_string_length: u8 = res[1];
//         for (0..n_strings) |i| {
//             if (i + 1 == string_idx) {}
//         }
//     } else {
//         return error.NoStringCatagory;
//     }
// }

// pub fn readSIIBytes(
//     port: *Port,
//     station_address: u16,
//     eeprom_address: u16,
//     skip_first_byte: bool,
//     out: []u8,
//     retries: u32,
//     recv_timeout_us: u32,
//     eeprom_timeout_us: u32,
// ) !void {
//     const n_4_bytes = try std.math.divCeil(usize, out.len, 4);
//     var fbs = std.io.fixedBufferStream(out);
//     var writer = fbs.writer();

//     for (0..n_4_bytes) |i| {
//         const source: [4]u8 = try readSII4ByteFP(
//             port,
//             station_address,
//             eeprom_address + 2 * @as(u16, @intCast(i)), // eeprom address is WORD address
//             retries,
//             recv_timeout_us,
//             eeprom_timeout_us,
//         );
//         for (source, 0..eeprom_address) |byte, position| {
//             if (i == 0 and position == 0 and skip_first_byte) continue;
//             writer.writeByte(byte) catch |err| switch (err) {
//                 error.NoSpaceLeft => {
//                     assert(i == n_4_bytes - 1);
//                     break;
//                 },
//             };
//         }
//     }
// }

pub const SIIStream = struct {
    port: *nic.Port,
    station_address: u16,
    retries: u32,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
    eeprom_address: u16, // WORD (2-byte) address

    last_four_bytes: [4]u8 = .{ 0, 0, 0, 0 },
    remainder: u8 = 0,

    pub fn init(
        port: *nic.Port,
        station_address: u16,
        eeprom_address: u16,
        retries: u32,
        recv_timeout_us: u32,
        eeprom_timeout_us: u32,
    ) SIIStream {
        return SIIStream{
            .port = port,
            .station_address = station_address,
            .eeprom_address = eeprom_address,
            .retries = retries,
            .recv_timeout_us = recv_timeout_us,
            .eeprom_timeout_us = eeprom_timeout_us,
        };
    }

    pub const ReadError = error{
        Timeout,
        SocketError,
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
                self.retries,
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
    SocketError,
};

/// read 4 bytes from SII, using station addressing
pub fn readSII4ByteFP(
    port: *nic.Port,
    station_address: u16,
    eeprom_address: u16,
    retries: u32,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
) ReadSIIError![4]u8 {

    // set eeprom access to main device
    for (0..retries) |_| {
        const wkc = commands.fpwrPack(
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
        ) catch |err| switch (err) {
            error.SocketError => return error.SocketError,
            error.NoTransactionAvailableTimeout => continue,
            error.FrameSerializationFailure => unreachable,
            error.CurruptedFrame => continue,
            error.RecvTimeout => continue,
        };
        if (wkc == 1) {
            break;
        }
    } else {
        return error.Timeout;
    }

    // ensure there is a rising edge in the read command by first sending zeros
    for (0..retries) |_| {
        var data = wire.zerosFromPack(esc.SIIControlStatusRegister);
        const wkc = commands.fpwr(
            port,
            .{
                .station_address = station_address,
                .offset = @intFromEnum(esc.RegisterMap.SII_control_status),
            },
            &data,
            recv_timeout_us,
        ) catch |err| switch (err) {
            error.SocketError => return error.SocketError,
            error.NoTransactionAvailableTimeout => continue,
            error.FrameSerializationFailure => unreachable,
            error.CurruptedFrame => continue,
            error.RecvTimeout => continue,
        };
        if (wkc == 1) {
            break;
        }
    } else {
        return error.Timeout;
    }

    // send read command
    for (0..retries) |_| {
        const wkc = commands.fpwrPack(
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
        ) catch |err| switch (err) {
            error.SocketError => return error.SocketError,
            error.NoTransactionAvailableTimeout => continue,
            error.FrameSerializationFailure => unreachable,
            error.CurruptedFrame => continue,
            error.RecvTimeout => continue,
        };
        if (wkc == 1) {
            break;
        }
    } else {
        return error.Timeout;
    }

    // TODO: timer interface
    var timer = Timer.start() catch @panic("timer unsupported");
    // wait for eeprom to be not busy
    while (timer.read() < eeprom_timeout_us * ns_per_us) {
        const sii_status = commands.fprdPack(
            port,
            esc.SIIControlStatusRegister,
            .{
                .station_address = station_address,
                .offset = @intFromEnum(
                    esc.RegisterMap.SII_control_status,
                ),
            },
            recv_timeout_us,
        ) catch |err| switch (err) {
            error.SocketError => return error.SocketError,
            error.NoTransactionAvailableTimeout => continue,
            error.FrameSerializationFailure => unreachable,
            error.CurruptedFrame => continue,
            error.RecvTimeout => continue,
        };

        if (sii_status.wkc != 1) {
            continue;
        }
        if (sii_status.ps.busy) {
            continue;
        } else {
            // check for eeprom nack
            if (sii_status.ps.command_error) {
                // TODO: this should never happen?
                continue;
            }
            break;
        }
    } else {
        return error.Timeout;
    }

    // attempt read 3 times
    for (0..retries) |_| {
        var data = [4]u8{ 0, 0, 0, 0 };
        const wkc = commands.fprd(
            port,
            .{
                .station_address = station_address,
                .offset = @intFromEnum(
                    esc.RegisterMap.SII_data,
                ),
            },
            &data,
            recv_timeout_us,
        ) catch |err| switch (err) {
            error.SocketError => return error.SocketError,
            error.NoTransactionAvailableTimeout => continue,
            error.FrameSerializationFailure => unreachable,
            error.CurruptedFrame => continue,
            error.RecvTimeout => continue,
        };
        if (wkc == 1) {
            return data;
        }
    } else {
        return error.Timeout;
    }
}
