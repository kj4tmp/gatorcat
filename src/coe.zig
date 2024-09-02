const commands = @import("commands.zig");
const nic = @import("nic.zig");
const config = @import("config.zig");

/// CoE Services
///
/// Ref: IEC 61158-6-12:2019 5.6.1
pub const Service = enum(u4) {
    emergency = 0x01,
    sdo_request = 0x02,
    sdo_response = 0x03,
    tx_pdo = 0x04,
    rx_pdo = 0x05,
    tx_pdo_remote_request = 0x06,
    rx_pdo_remote_request = 0x07,
    sdo_info = 0x08,
    _,
};

pub const CoEHeader = packed struct {
    number: u9 = 0,
    reserved: u3 = 0,
    service: Service,
};

pub const TransferType = enum(u1) {
    normal = 0x00,
    expedited = 0x01,
};

pub const DataSetSize = enum(u2) {
    four_octets = 0x00,
    three_octets = 0x01,
    two_octets = 0x02,
    one_octet = 0x03,
};

pub const CommandSpecifier = enum(u3) {
    download_request = 0x01,
    upload_request_or_response = 0x02,
    download_response = 0x03,
    _,
};

/// Mailbox Types
///
/// Ref: IEC 61158-4-12:2019 5.6
pub const MailboxType = enum(u4) {
    /// error
    ERR = 0x00,
    /// ADS over EtherCAT (AoE)
    AoE,
    /// Ethernet over EtherCAT (EoE)
    EoE,
    /// CAN Application Protocol over EtherCAT (CoE)
    CoE,
    /// File Access over EtherCAT (FoE)
    FoE,
    /// Servo Drive Profile over EtherCAT (SoE)
    SoE,
    /// Vendor Specfic over EtherCAT (VoE)
    VoE = 0x0f,
};

pub const MailboxErrorCode = enum(u16) {
    /// syntax of 6 octet mailbox header is wrong
    syntax = 0x01,
    /// specified mailbox protocol is not supported
    unsupported_protocol,
    /// channel field contains wrong value (a subdevice can ignore the channel field)
    invalid_channel,
    /// service in the mailbox protocol is not supported
    service_not_supported,
    /// mailbox protocl header of the mailbox protocol is wrong (without
    /// the 6 octet mailbox header)
    invalid_header,
    /// length of the recieved mailbox data is too short
    size_too_short,
    /// mailbox protocol cannot be processed because of limited resources,
    no_more_memory,
    /// length of the data is inconsistent
    invalid_size,
    /// mailbox service already in use
    service_in_work,
};

/// Mailbox Error Reply
///
/// Ref: IEC 61158-4-12:2019 5.6
pub const MailboxErrorReplyServiceData = struct {
    type: u16, // 0x01: mailbox command
    detail: MailboxErrorCode,
};

pub const StationAddress = u16;

/// Mailbox Header
///
/// Ref: IEC 61158-4-12:2019 5.6
pub const MailboxHeader = packed struct {
    /// length of mailbox service data
    length: u16,
    address: StationAddress,
    /// reserved
    channel: u6,
    /// 0: lowest priority, 3: highest priority
    priority: u2,
    /// type of mailbox communication
    type: MailboxType,
    /// counter for the mailbox services
    /// zero is reserved. 1 is start value. next value after 7 is 1.
    ///
    /// SubDevice shall increment the counter for each new mailbox service. The maindevice
    /// shall check this for detection of lost mailbox services. The maindevice shall
    /// increment the counter value before retrying and the subdevice shall check for this
    /// for detection of repeat service. The subdevice shall not check the sequence of the
    /// counter value. The maindevice and the subdevice counters are independent.
    cnt: u3,
    reserved: u1 = 0,
};

/// Mailbox
///
/// Mailbox communication data. Goes in data field of datagram.
///
/// Ref: IEC 61158-4-12:2019 5.6
pub const Mailbox = struct {
    header: MailboxHeader,
    /// mailbox service data
    data: []u8,
};

/// SDO Download Expedited Request
///
/// Ref: IEC 61158-6-12:2019 5.6.2.1.1
pub const SDODownloadExpeditedRequest = packed struct(u128) {
    header: MailboxHeader,
    coe_header: CoEHeader = .{ .service = .sdo_request },
    size_specified: bool = true,
    transfer_type: TransferType = .expedited,
    data_set_size: DataSetSize,
    /// false: entry addressed with index and subindex will be downloaded.
    /// true: complete object will be downlaoded. subindex shall be zero (when subindex zero
    /// is to be included) or one (subindex 0 excluded)
    complete_access: bool,
    /// 0x01 = download request
    command_specifier: CommandSpecifier = .download_request,
    index: u16,
    /// shal be zero or one if complete access is true.
    subindex: u8,
    /// 4 bytes, but in current zig, packed structs cannot contain arrays
    data: u32,
};

/// SDO Download Expedited Response
///
/// Ref: IEC 61158-6-12:2019 5.6.2.1.2
pub const SDODownloadExpeditedResponse = packed struct(u128) {
    header: MailboxHeader,
    coe_header: CoEHeader = .{ .service = .sdo_response },
    size_specified: bool = false,
    transfer_type: u1 = 0,
    data_set_size: u2 = 0,
    complete_access: bool = false,
    command_specifier: CommandSpecifier = .download_response,
    index: u16,
    /// shall be zero or one if complete access is true
    subindex: u8,
    reserved: u32 = 0,
};

/// SDO Upload Expedited Request
///
/// Ref: IEC 61158-6-12:2019 5.6.2.4.1
pub const SDOUploadExpeditedRequest = packed struct(u128) {
    header: MailboxHeader,
    coe_header: CoEHeader = .{ .service = .sdo_request },
    reserved: u4 = 0,
    complete_access: bool,
    command_specifier: CommandSpecifier = .upload_request_or_response,
    index: u16,
    subindex: u8,
    reserved2: u32 = 0,
};

/// SDO Upload Expedited Response
///
/// Ref: IEC 61158-6-12:2019 5.6.2.4.2
pub const SDOUploadExpeditedResponse = packed struct(u128) {
    header: MailboxHeader,
    coe_header: CoEHeader = .{ .service = .sdo_response },
    size_specified: bool = true,
    transfer_type: TransferType = .expedited,
    data_set_size: DataSetSize,
    complete_access: bool,
    command_specifer: CommandSpecifier = .upload_request_or_response,
    index: u16,
    subindex: u8,
    data: u32,
};

pub fn sdoReadExpedited(
    port: *nic.Port,
    station_address: u16,
    index: u16,
    subindex: u8,
    recv_timeout_us: u32,
    mbx_timeout_us: u32,
) !void![4]u8 {}
