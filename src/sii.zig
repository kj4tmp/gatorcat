//! Subdevice Information Interface (SII)
//!
//! Address is word (two-byte) address.

const nic = @import("nic.zig");
const Port = nic.Port;
const eCatFromPack = nic.eCatFromPack;
const packFromECat = nic.packFromECat;

const std = @import("std");
const Timer = std.time.Timer;
const ns_per_us = std.time.ns_per_us;
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

pub const MailboxProtocolSupported = packed struct(u16) {
    AoE: bool,
    EoE: bool,
    CoE: bool,
    FoE: bool,
    SoE: bool,
    VoE: bool,
    reserved: u10 = 0,
};

pub const SubdeviceInfo = packed struct {
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

pub const SubdeviceIdentity = packed struct {
    vendor_id: u32,
    product_code: u32,
    revision_number: u32,
};

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
    _,
};

pub const CatagoryHeader = packed struct {
    catagory_type: CatagoryType,
    vendor_specific: u1,
    word_size: u16,
};

/// read a packed struct from SII
pub fn readSII_ps(
    port: *Port,
    comptime T: type,
    autoinc_address: u16,
    eeprom_address: u16,
    retries: u32,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
) !T {
    const n_4_bytes = @divExact(@bitSizeOf(T), 32);
    var bytes: [@divExact(@bitSizeOf(T), 8)]u8 = undefined;

    for (0..n_4_bytes) |i| {
        const source = try readSII4Byte(
            port,
            autoinc_address,
            eeprom_address + 2 * @as(u16, @intCast(i)), // eeprom address is WORD address
            retries,
            recv_timeout_us,
            eeprom_timeout_us,
        );
        @memcpy(bytes[i * 4 .. i * 4 + 4], &source);
    }

    return nic.packFromECat(T, bytes);
}

/// read 4 bytes from SII
pub fn readSII4Byte(
    port: *Port,
    autoinc_address: u16,
    eeprom_address: u16,
    retries: u32,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
) ![4]u8 {

    // set eeprom access to main device
    for (0..retries) |_| {
        const wkc = try commands.APWR_ps(
            port,
            esc.SIIAccessRegisterCompact{
                .owner = .ethercat_DL,
                .lock = false,
            },
            .{
                .autoinc_address = autoinc_address,
                .offset = @intFromEnum(esc.RegisterMap.SII_access),
            },
            recv_timeout_us,
        );
        if (wkc == 1) {
            break;
        }
    } else {
        return error.SubdeviceUnresponsive;
    }

    // ensure there is a rising edge in the read command by first sending zeros
    for (0..retries) |_| {
        var data = nic.zerosFromPack(esc.SIIControlStatusRegister);
        const wkc = try commands.APWR(
            port,
            .{
                .autoinc_address = autoinc_address,
                .offset = @intFromEnum(esc.RegisterMap.SII_control_status),
            },
            &data,
            recv_timeout_us,
        );
        if (wkc == 1) {
            break;
        }
    } else {
        return error.SubdeviceUnresponsive;
    }

    // send read command
    for (0..retries) |_| {
        const wkc = try commands.APWR_ps(
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
                .autoinc_address = autoinc_address,
                .offset = @intFromEnum(esc.RegisterMap.SII_control_status),
            },
            recv_timeout_us,
        );
        if (wkc == 1) {
            break;
        }
    } else {
        return error.SubdeviceUnresponsive;
    }

    var timer = try Timer.start();
    // wait for eeprom to be not busy
    while (timer.read() < eeprom_timeout_us * ns_per_us) {
        const sii_status = try commands.APRD_ps(
            port,
            esc.SIIControlStatusRegister,
            .{
                .autoinc_address = autoinc_address,
                .offset = @intFromEnum(
                    esc.RegisterMap.SII_control_status,
                ),
            },
            recv_timeout_us,
        );

        if (sii_status.wkc != 1) {
            continue;
        }
        if (sii_status.ps.busy) {
            continue;
        } else {
            // check for eeprom nack
            if (sii_status.ps.command_error) {
                return error.eepromCommandError;
            }
            break;
        }
    } else {
        return error.eepromTimeout;
    }

    // attempt read 3 times
    for (0..retries) |_| {
        var data = [4]u8{ 0, 0, 0, 0 };
        const wkc = try commands.APRD(
            port,
            .{
                .autoinc_address = autoinc_address,
                .offset = @intFromEnum(
                    esc.RegisterMap.SII_data,
                ),
            },
            &data,
            recv_timeout_us,
        );
        if (wkc == 1) {
            return data;
        }
    } else {
        return error.SubdeviceUnresponsive;
    }
}
