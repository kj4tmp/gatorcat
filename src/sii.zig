//! Subdevice Information Interface (SII)
//!
//! Address is word (two-byte) address.

const nic = @import("nic.zig");
const Port = nic.Port;
const eCatFromPack = nic.eCatFromPack;
const packFromECat = nic.packFromECat;

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
