const std = @import("std");
const Timer = std.time.Timer;
const ns_per_us = std.time.ns_per_us;
const assert = std.debug.assert;

const commands = @import("commands.zig");
const nic = @import("nic.zig");
const config = @import("config.zig");
const esc = @import("esc.zig");
const telegram = @import("telegram.zig");

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

pub const CoEHeader = packed struct(u16) {
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

/// Client Command Specifer
///
/// Ref: IEC 61158-6-12:2019 5.6.2.1.1
/// The spec refers to this as a "command specifier".
/// CoE is a wrapper on CANopen. In the CANopen specificaiton,
/// this is actually separated between client command specifier (CCS) and
/// server command specifier (scs).
///
/// Ref: CiA 301 V4.2.0
pub const ClientCommandSpecifier = enum(u3) {
    download_segment_request = 0,
    initiate_download_request = 1,
    initiate_upload_request = 2,
    upload_segment_request = 3,
    abort_transfer_request = 4,
    block_upload = 5,
    block_download = 6,
};

/// Server Command Specifier
///
/// See Client Command Specifier.
pub const ServerCommandSpecifier = enum(u3) {
    upload_segment_response = 0,
    download_segment_response = 1,
    initiate_upload_response = 2,
    initiate_download_response = 3,
    abort_transfer_request = 4,
    block_download = 5,
    block_upload = 6,
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
    _,
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
pub const MailboxHeader = packed struct(u48) {
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
    mbx_header: MailboxHeader,
    /// mailbox service data
    data: []u8,
};

/// SDO Header for CoE for maindevice to subdevice (client to server)
/// messages.
///
/// Ref: IEC 61158-6-12
pub const SDOHeaderClient = packed struct(u32) {
    size_indicator: bool,
    transfer_type: TransferType,
    data_set_size: DataSetSize,
    /// false: entry addressed with index and subindex will be downloaded.
    /// true: complete object will be downlaoded. subindex shall be zero (when subindex zero
    /// is to be included) or one (subindex 0 excluded)
    complete_access: bool,
    command: ClientCommandSpecifier,
    index: u16,
    /// shall be zero or one if complete access is true.
    subindex: u8,
};

/// SDO Header for CoE for subdevice to maindevice (server to client)
/// messages.
///
/// Ref: IEC 61158-6-12
pub const SDOHeaderServer = packed struct(u32) {
    size_indicator: bool,
    transfer_type: TransferType,
    data_set_size: DataSetSize,
    /// false: entry addressed with index and subindex will be downloaded.
    /// true: complete object will be downlaoded. subindex shall be zero (when subindex zero
    /// is to be included) or one (subindex 0 excluded)
    complete_access: bool,
    command: ServerCommandSpecifier,
    index: u16,
    /// shall be zero or one if complete access is true.
    subindex: u8,
};

pub const SDOClientExpedited = packed struct(u128) {
    mbx_header: MailboxHeader,
    coe_header: CoEHeader,
    sdo_header: SDOHeaderClient,
    data: u32,

    /// Create an SDO Download Expedited Request
    ///
    /// data must be between 1 and 4 bytes long
    ///
    /// Ref: IEC 61158-6-12:2019 5.6.2.1.1
    pub fn initDownload(
        cnt: u3,
        index: u16,
        subindex: u8,
        data: [4]u8,
    ) SDOClientExpedited {
        assert(cnt != 0);
        const size: DataSetSize = switch (data.len) {
            1 => .one_octet,
            2 => .two_octets,
            3 => .three_octets,
            4 => .four_octets,
            else => unreachable,
        };

        return SDOClientExpedited{
            .mbx_header = .{
                .length = 0x0A,
                .address = 0,
                .channel = 0,
                .priority = 0,
                .type = .CoE,
                .cnt = cnt,
            },
            .coe_header = .{
                .number = 0,
                .service = .sdo_request,
            },
            .sdo_header = .{
                .size_indicator = true,
                .transfer_type = .expedited,
                .data_set_size = size,
                .complete_access = false,
                .command = .initiate_download_request,
                .index = index,
                .subindex = subindex,
            },
            .data = @bitCast(data),
        };
    }

    /// Create an SDO Upload Expedited Request or
    /// an SDO Upload Normal Request (they have the same coding).
    ///
    /// Ref: IEC 61158-6-12:2019 5.6.2.4.1
    pub fn initUpload(
        cnt: u3,
        index: u16,
        subindex: u8,
    ) SDOClientExpedited {
        assert(cnt != 0);
        return SDOClientExpedited{
            .mbx_header = .{
                .length = 0x0A,
                .address = 0,
                .channel = 0,
                .priority = 0,
                .type = .CoE,
                .cnt = cnt,
            },
            .coe_header = .{
                .number = 0,
                .service = .sdo_request,
            },
            // first 4 bits are reserved to be zero
            .sdo_header = .{
                .size_indicator = @bitCast(@as(u1, 0)),
                .transfer_type = @bitCast(@as(u1, 0)),
                .data_set_size = @bitCast(@as(u2, 0)),
                .complete_access = false,
                .command = .initiate_upload_request,
                .index = index,
                .subindex = subindex,
            },
            // last 4 bytes are reserved as zero
            .data = 0,
        };
    }

    pub fn deserialize(buf: []const u8) !SDOClientExpedited {
        var fbs = std.io.fixedBufferStream(buf);
        var reader = fbs.reader();
        return try nic.packFromECatReader(SDOClientExpedited, &reader);
    }

    pub fn serialize(self: SDOClientExpedited, out: []u8) !usize {
        var fbs = std.io.fixedBufferStream(out);
        const writer = fbs.writer();
        try nic.eCatFromPackToWriter(self, writer);
        return fbs.getWritten().len;
    }
};

test "serialize deserialize sdo client expedited" {
    const expected = SDOClientExpedited.initDownload(
        5,
        1234,
        23,
        .{ 1, 2, 3, 4 },
    );

    var bytes = std.mem.zeroes([max_mailbox_size]u8);
    const byte_size = try expected.serialize(&bytes);
    try std.testing.expectEqual(@as(usize, 6 + 2 + 8), byte_size);
    const actual = try SDOClientExpedited.deserialize(&bytes);
    try std.testing.expectEqualDeep(expected, actual);
}

pub const SDOClientNormal = struct {
    mbx_header: MailboxHeader,
    coe_header: CoEHeader,
    sdo_header: SDOHeaderClient,
    complete_size: u32,
    data: std.BoundedArray(u8, data_max_size),

    pub const data_max_size = max_mailbox_size - 16;

    /// Create an SDO Download Normal Request
    ///
    /// Ref: IEC 61158-6-12:2019 5.6.2.2.1
    /// Ref: IEC 61158-6-12:2019 5.6.2.5.1
    pub fn initDownload(
        cnt: u3,
        index: u16,
        subindex: u8,
        complete_size: u32,
        data: []const u8,
    ) !SDOClientNormal {
        assert(cnt != 0);
        return SDOClientNormal{
            .mbx_header = .{
                .length = @as(u16, @intCast(data.len)) + 10,
                .address = 0x0,
                .channel = 0,
                .priority = 0,
                .type = .CoE,
                .cnt = cnt,
            },
            .coe_header = .{
                .number = 0,
                .service = .sdo_request,
            },
            .sdo_header = .{
                .size_indicator = true,
                .transfer_type = .normal,
                .data_set_size = .four_octets,
                .complete_access = false,
                .command = .initiate_download_request,
                .index = index,
                .subindex = subindex,
            },
            .complete_size = complete_size,
            .data = try std.BoundedArray(u8, data_max_size).fromSlice(data),
        };
    }

    pub fn deserialize(buf: []const u8) !SDOClientNormal {
        var fbs = std.io.fixedBufferStream(buf);
        const reader = fbs.reader();
        const mbx_header = try nic.packFromECatReader(MailboxHeader, reader);
        const coe_header = try nic.packFromECatReader(CoEHeader, reader);
        const sdo_header = try nic.packFromECatReader(SDOHeaderClient, reader);
        const complete_size = try nic.packFromECatReader(u32, reader);

        if (mbx_header.length < 10) {
            return error.InvalidMbxHeaderLength;
        }
        const data_length: u16 = mbx_header.length -| 10;
        var data = try std.BoundedArray(u8, data_max_size).init(data_length);
        try reader.readNoEof(data.slice());

        return SDOClientNormal{
            .mbx_header = mbx_header,
            .coe_header = coe_header,
            .sdo_header = sdo_header,
            .complete_size = complete_size,
            .data = data,
        };
    }

    pub fn serialize(self: *const SDOClientNormal, out: []u8) !usize {
        var fbs = std.io.fixedBufferStream(out);
        const writer = fbs.writer();
        try nic.eCatFromPackToWriter(self.mbx_header, writer);
        try nic.eCatFromPackToWriter(self.coe_header, writer);
        try nic.eCatFromPackToWriter(self.sdo_header, writer);
        try nic.eCatFromPackToWriter(self.complete_size, writer);
        try writer.writeAll(self.data.slice());
        return fbs.getWritten().len;
    }

    comptime {
        assert(data_max_size ==
            max_mailbox_size -
            @divExact(@bitSizeOf(MailboxHeader), 8) -
            @divExact(@bitSizeOf(CoEHeader), 8) -
            @divExact(@bitSizeOf(SDOHeaderClient), 8) -
            @divExact(@bitSizeOf(u32), 8));
    }
};

test "serialize deserialize SDO client normal" {
    const expected = try SDOClientNormal.initDownload(
        2,
        1000,
        23,
        12345,
        &.{ 1, 2, 3 },
    );

    var bytes = std.mem.zeroes([max_mailbox_size]u8);
    const byte_size = try expected.serialize(&bytes);
    try std.testing.expectEqual(@as(usize, 6 + 2 + 8 + 3), byte_size);
    const actual = try SDOClientNormal.deserialize(&bytes);
    try std.testing.expectEqualDeep(expected, actual);
}

///
pub const SDOClientSegment = struct {
    mbx_header: MailboxHeader,
    coe_header: CoEHeader,
    sdo_seg_header: SDOSegmentHeaderClient,
    data: std.BoundedArray(u8, data_max_size),

    pub const data_max_size = max_mailbox_size - 12;

    /// Create an SDO Download Segmented Request
    ///
    /// Ref: IEC 61158-6-12:2019 5.6.2.3.1
    pub fn initDownload(
        cnt: u3,
        more_follows: bool,
        toggle: bool,
        data: []const u8,
    ) !SDOClientSegment {
        assert(cnt != 0);
        const length = @max(10, @as(u16, @intCast(data.len + 3)));

        const seg_data_size: SegmentDataSize = switch (data.len) {
            0 => .zero_octets,
            1 => .one_octet,
            2 => .two_octets,
            3 => .three_octets,
            4 => .four_octets,
            5 => .five_octets,
            6 => .six_octets,
            else => .seven_octets,
        };

        return SDOClientSegment{
            .mbx_header = .{
                .length = length,
                .address = 0x0,
                .channel = 0,
                .priority = 0,
                .type = .CoE,
                .cnt = cnt,
            },
            .coe_header = .{
                .number = 0,
                .service = .sdo_request,
            },
            .sdo_seg_header = .{
                .more_follows = more_follows,
                .seg_data_size = seg_data_size,
                .toggle = toggle,
                .command = .download_segment_request,
            },
            .data = try std.BoundedArray(u8, data_max_size).fromSlice(data),
        };
    }

    /// Create an SDO Upload Segmented Request
    ///
    /// Ref: IEC 61158-6-12:2019 5.6.2.6.1
    pub fn initUpload(
        cnt: u3,
        toggle: bool,
    ) SDOClientSegment {
        assert(cnt != 0);
        return SDOClientSegment{
            .mbx_header = .{
                .length = 10,
                .address = 0x0,
                .channel = 0,
                .priority = 0,
                .type = .CoE,
                .cnt = cnt,
            },
            .coe_header = .{
                .number = 0,
                .service = .sdo_request,
            },
            .sdo_seg_header = .{
                .toggle = toggle,
                .command = .upload_segment_request,
            },
            .data = std.BoundedArray(u8, data_max_size).fromSlice(&.{ 0, 0, 0, 0, 0, 0, 0 }) catch unreachable,
        };
    }

    pub fn deserialize(buf: []const u8) !SDOClientSegment {
        var fbs = std.io.fixedBufferStream(buf);
        const reader = fbs.reader();
        const mbx_header = try nic.packFromECatReader(MailboxHeader, reader);
        const coe_header = try nic.packFromECatReader(CoEHeader, reader);
        const sdo_seg_header = try nic.packFromECatReader(SDOSegmentHeaderClient, reader);

        if (mbx_header.length < 10) {
            return error.InvalidMbxHeaderLength;
        }
        const data_length: u16 = mbx_header.length -| 3;
        var data = try std.BoundedArray(u8, data_max_size).init(data_length);
        try reader.readNoEof(data.slice());

        return SDOClientSegment{
            .mbx_header = mbx_header,
            .coe_header = coe_header,
            .sdo_seg_header = sdo_seg_header,
            .data = data,
        };
    }

    pub fn serialize(self: *const SDOClientSegment, out: []u8) !usize {
        var fbs = std.io.fixedBufferStream(out);
        const writer = fbs.writer();
        try nic.eCatFromPackToWriter(self.mbx_header, writer);
        try nic.eCatFromPackToWriter(self.coe_header, writer);
        try nic.eCatFromPackToWriter(self.sdo_seg_header, writer);
        try writer.writeAll(self.data.slice());
        return fbs.getWritten().len;
    }

    comptime {
        assert(data_max_size ==
            max_mailbox_size -
            @divExact(@bitSizeOf(MailboxHeader), 8) -
            @divExact(@bitSizeOf(CoEHeader), 8) -
            @divExact(@bitSizeOf(SDOHeaderClient), 8));
    }

    comptime {
        assert(data_max_size >= 7); // must be able to fit upload request
    }
};

test "serialize deserialize sdo client segment" {
    const expected = try SDOClientSegment.initDownload(
        3,
        true,
        true,
        &.{ 1, 2, 3, 4, 5, 6, 7 },
    );

    var bytes = std.mem.zeroes([max_mailbox_size]u8);
    const byte_size = try expected.serialize(&bytes);
    try std.testing.expectEqual(@as(usize, 6 + 2 + 8), byte_size);
    const actual = try SDOClientSegment.deserialize(&bytes);
    try std.testing.expectEqualDeep(expected, actual);
}

test "sdo client segment seg_data_size" {
    const actual = try SDOClientSegment.initDownload(
        3,
        true,
        true,
        &.{ 1, 2, 3, 4 },
    );
    try std.testing.expectEqual(SegmentDataSize.four_octets, actual.sdo_seg_header.seg_data_size);
}

/// SDO Expedited Responses
///
/// The coding for the SDO Download Normal Response is the same
/// as the SDO Download Expedited Response.
///
/// Ref: IEC 61158-6-12:2019 5.6.2.1.2 (SDO Download Expedited Response)
/// Ref: IEC 61158-6-12:2019 5.6.2.2.2 (SDO Download Normal Response)
/// Ref: IEC 61158-6-12:2019 5.6.2.4.2 (SDO Upload Expedited Response)
pub const SDOServerExpedited = packed struct(u128) {
    mbx_header: MailboxHeader,
    coe_header: CoEHeader,
    sdo_header: SDOHeaderServer,
    data: u32 = 0,

    pub fn deserialize(buf: []const u8) SDOServerExpedited {
        var fbs = std.io.fixedBufferStream(buf);
        var reader = fbs.reader();
        return nic.packFromECatReader(SDOServerExpedited, &reader);
    }

    pub fn serialize(self: SDOServerExpedited, out: []u8) !usize {
        var fbs = std.io.fixedBufferStream(out);
        const writer = fbs.writer();
        try nic.eCatFromPackToWriter(self, writer);
        return fbs.getWritten().len;
    }
};

pub const SDOServerNormal = struct {
    mbx_header: MailboxHeader,
    coe_header: CoEHeader,
    sdo_header: SDOHeaderServer,
    complete_size: u32,
    data: std.BoundedArray(u8, data_max_size),

    pub const data_max_size = max_mailbox_size - 16;

    pub fn deserialize(buf: []const u8) !SDOServerNormal {
        var fbs = std.io.fixedBufferStream(buf);
        const reader = fbs.reader();
        const mbx_header = try nic.packFromECatReader(MailboxHeader, reader);
        const coe_header = try nic.packFromECatReader(CoEHeader, reader);
        const sdo_header = try nic.packFromECatReader(SDOHeaderServer, reader);
        const complete_size = try nic.packFromECatReader(u32, reader);

        if (mbx_header.length < 10) {
            return error.InvalidMbxHeaderLength;
        }
        const data_length: u16 = mbx_header.length -| 10;
        var data = try std.BoundedArray(u8, data_max_size).init(data_length);
        try reader.readNoEof(data.slice());

        return SDOServerNormal{
            .mbx_header = mbx_header,
            .coe_header = coe_header,
            .sdo_header = sdo_header,
            .complete_size = complete_size,
            .data = data,
        };
    }

    pub fn serialize(self: *const SDOServerNormal, out: []u8) !usize {
        var fbs = std.io.fixedBufferStream(out);
        const writer = fbs.writer();
        try nic.eCatFromPackToWriter(self.mbx_header, writer);
        try nic.eCatFromPackToWriter(self.coe_header, writer);
        try nic.eCatFromPackToWriter(self.sdo_header, writer);
        try nic.eCatFromPackToWriter(self.complete_size, writer);
        try writer.writeAll(self.data.slice());
        return fbs.getWritten().len;
    }

    comptime {
        assert(data_max_size == max_mailbox_size -
            @divExact(@bitSizeOf(MailboxHeader), 8) -
            @divExact(@bitSizeOf(CoEHeader), 8) -
            @divExact(@bitSizeOf(SDOHeaderServer), 8) -
            @divExact(@bitSizeOf(u32), 8));
    }
};

test "serialize and deserialize sdo server normal" {
    const expected = SDOServerNormal{
        .mbx_header = .{
            .length = 14, // 4 bytes of payload
            .address = 0x0,
            .channel = 0,
            .priority = 0,
            .type = .CoE,
            .cnt = 2,
        },
        .coe_header = .{
            .number = 0,
            .service = .sdo_response,
        },
        .sdo_header = .{
            .size_indicator = true,
            .transfer_type = .normal,
            .data_set_size = .four_octets,
            .complete_access = false,
            .command = .initiate_upload_response,
            .index = 1234,
            .subindex = 0,
        },
        .complete_size = 12345,
        .data = try std.BoundedArray(u8, SDOServerNormal.data_max_size).fromSlice(&.{ 1, 2, 3, 4 }),
    };
    var bytes = std.mem.zeroes([max_mailbox_size]u8);
    const byte_size = try expected.serialize(&bytes);
    try std.testing.expectEqual(@as(usize, 6 + 2 + 12), byte_size);
    const actual = try SDOServerNormal.deserialize(&bytes);
    try std.testing.expectEqualDeep(expected, actual);
}

pub const SegmentDataSize = enum(u3) {
    seven_octets = 0x00,
    six_octets = 0x01,
    five_octets = 0x02,
    four_octets = 0x03,
    three_octets = 0x04,
    two_octets = 0x05,
    one_octet = 0x06,
    zero_octets = 0x07,
};

/// SDO Segment Header Client
///
/// Client / server language is from CANopen.
///
/// Ref: IEC 61158-6-12:2019 5.6.2.3.1
pub const SDOSegmentHeaderClient = packed struct {
    more_follows: bool,
    seg_data_size: SegmentDataSize,
    /// shall toggle with every segment, starting with 0x00
    toggle: bool,
    command: ClientCommandSpecifier,
};

/// SDO Segment Header Server
///
/// Client / server language is from CANopen.
///
/// Ref: IEC 61158-6-12:2019 5.6.2.3.1
pub const SDOSegmentHeaderServer = packed struct {
    more_follows: bool,
    seg_data_size: SegmentDataSize,
    /// shall toggle with every segment, starting with 0x00
    toggle: bool,
    command: ServerCommandSpecifier,
};

/// SDO Download Segment Response
///
/// Ref: IEC 61158-6-12:2019 5.6.2.3.2
pub const SDODownloadSegmentResponse = packed struct {
    mbx_header: MailboxHeader,
    coe_header: CoEHeader,
    seg_header: SDOSegmentHeaderServer,
    /// 7 bytes
    reserved: u56,
};

/// SDO Upload Normal Response
///
/// Ref: IEC 61158-6-12:2019 5.6.2.5.2
pub const SDOUploadNormalResponse = struct {
    mbx_header: MailboxHeader,
    coe_header: CoEHeader,
    sdo_header: SDOHeaderServer,
    complete_size: u23,
    data: []u8,
};

/// SDO Upload Segment Response
///
/// Ref: IEC 61158-6-12:2019 5.6.2.6.2
pub const SDOUploadSegmentResponse = struct {
    mbx_header: MailboxHeader,
    coe_header: CoEHeader,
    seg_header: SDOSegmentHeaderServer,
    data: []u8,
};

/// SDO Abort Codes
///
/// Ref: IEC 61158-6-12:2019 5.6.2.7.2
pub const SDOAbortCode = enum(u32) {
    ToggleBitNotChanged = 0x05_03_00_00,
    SdoProtocolTimeout = 0x05_04_00_00,
    ClientServerCommandSpecifierNotValidOrUnknown = 0x05_04_00_01,
    OutOfMemory = 0x05_04_00_05,
    UnsupportedAccessToAnObject = 0x06_01_00_00,
    AttemptToReadToAWriteOnlyObject = 0x06_01_00_01,
    AttemptToWriteToAReadOnlyObject = 0x06_01_00_02,
    SubindexCannotBeWritten = 0x06_01_00_03,
    SdoCompleteAccessNotSupportedForVariableLengthObjects = 0x06_01_00_04,
    ObjectLengthExceedsMailboxSize = 0x06_01_00_05,
    ObjectMappedToRxPdoSdoDownloadBlocked = 0x06_01_00_06,
    ObjectDoesNotExistInObjectDirectory = 0x06_02_00_00,
    ObjectCannotBeMappedIntoPdo = 0x06_04_00_41,
    NumberAndLengthOfObjectsExceedsPdoLength = 0x06_04_00_42,
    GeneralParameterIncompatibilityReason = 0x06_04_00_43,
    GeneralInternalIncompatibilityInDevice = 0x06_04_00_47,
    AccessFailedDueToHardwareError = 0x06_06_00_00,
    DataTypeMismatchLengthOfServiceParameterDoesNotMatch = 0x06_07_00_10,
    DataTypeMismatchLengthOfServiceParameterTooHigh = 0x06_07_00_12,
    DataTypeMismatchLengthOfServiceParameterTooLow = 0x06_07_00_13,
    SubindexDoesNotExist = 0x06_09_00_11,
    ValueRangeOfParameterExceeded = 0x06_09_00_30,
    ValueOfParameterWrittenTooHigh = 0x06_09_00_31,
    ValueOfParameterWrittenTooLow = 0x06_09_00_32,
    MaximumValueLessThanMinimumValue = 0x06_09_00_36,
    GeneralError = 0x08_00_00_00,
    DataCannotBeTransferredOrStoredToApplication = 0x08_00_00_20,
    DataCannotBeTransferredOrStoredDueToLocalControl = 0x08_00_00_21,
    DataCannotBeTransferredOrStoredDueToESMState = 0x08_00_00_22,
    ObjectDictionaryDynamicGenerationFailedOrNoObjectDictionaryPresent = 0x08_00_00_23,
};

/// Abort SDO Transfer Request
///
/// Ref: IEC 61158-6-12:2019 5.6.2.7.1
pub const AbortSDOTransferRequest = packed struct {
    mbx_header: MailboxHeader,
    coe_header: CoEHeader,
    /// SDOHeaderClient is arbitrarily chosen here.
    /// Abort has no concept of client / server.
    sdo_header: SDOHeaderClient,
    abort_code: SDOAbortCode,
};

/// SDO Info Op Codes
///
/// Ref: IEC 61158-6-12:2019 5.6.3.2
pub const SDOInfoOpCode = enum(u7) {
    get_od_list_request = 0x01,
    get_od_list_respoonse = 0x02,
    get_object_description_request = 0x03,
    get_object_description_response = 0x04,
    get_entry_description_request = 0x05,
    get_entry_description_response = 0x06,
    sdo_info_error_request = 0x07,
};

/// SDO Info Header
///
/// Ref: IEC 61158-6-12:2019 5.6.3.2
pub const SDOInfoHeader = packed struct {
    opcode: SDOInfoOpCode,
    incomplete: bool,
    reserved: u8 = 0,
    fragments_left: u16,
};

/// OD List Types
///
/// Ref: IEC 61158-6-12:2019 5.6.3.3.1
pub const ODListType = enum(u16) {
    num_object_in_5_lists = 0x00,
    all_objects = 0x01,
    rxpdo_mappable = 0x02,
    txpdo_mappable = 0x03,
    device_replacement_stored = 0x04, // what does this mean?
    startup_parameters = 0x05,
};

/// Get OD List Request
///
/// Ref: IEC 61158-6-12:2019 5.6.3.3.1
pub const GetODListRequest = packed struct {
    mbx_header: MailboxHeader,
    coe_header: CoEHeader,
    sdo_info_header: SDOInfoHeader,
    list_type: ODListType,

    pub fn init(
        cnt: u3,
        list_type: ODListType,
    ) GetODListRequest {
        assert(cnt != 0);
        return GetODListRequest{
            .mbx_header = .{
                .length = 8,
                .address = 0,
                .channel = 0,
                .priority = 0,
                .type = .CoE,
                .cnt = cnt,
            },
            .coe_header = .{
                .number = 0,
                .service = .sdo_info,
            },
            .sdo_info_header = .{
                .opcode = .get_od_list_request,
                .incomplete = false,
                .fragments_left = 0,
            },
            .list_type = list_type,
        };
    }
};

/// Get OD List Response
///
/// Ref: IEC 61158-6-12:2019 5.6.3.3.2
pub const GetODListResponse = struct {
    mbx_header: MailboxHeader,
    coe_header: CoEHeader,
    sdo_info_header: SDOInfoHeader,
    list_type: ODListType,
    index_list: []u16,
};

/// Get Object Description Request
///
/// Ref: IEC 61158-6-12:2019 5.6.3.5.1
pub const GetObjectDescriptionRequest = packed struct {
    mbx_header: MailboxHeader,
    coe_header: CoEHeader,
    sdo_info_header: SDOInfoHeader,
    index: u16,

    pub fn init(
        cnt: u3,
        index: u16,
    ) GetObjectDescriptionRequest {
        assert(cnt != 0);
        return GetObjectDescriptionRequest{
            .mbx_header = .{
                .length = 8,
                .address = 0,
                .channel = 0,
                .priority = 0,
                .type = .CoE,
                .cnt = cnt,
            },
            .coe_header = .{
                .number = 0,
                .service = .sdo_info,
            },
            .sdo_info_header = .{
                .opcode = .get_object_description_request,
                .incomplete = false,
                .fragments_left = false,
            },
            .index = index,
        };
    }
};

/// Object Code
///
/// Ref: IEC 61158-6-12:2019 5.6.3.5.2
pub const ObjectCode = enum(u8) {
    variable = 7,
    array = 8,
    record = 9,
    _,
};

/// Get Object Description Response
///
/// Ref: IEC 61158-6-12:2019 5.6.3.5.2
pub const GetObjectDescriptionResponse = struct {
    mbx_header: MailboxHeader,
    coe_header: CoEHeader,
    sdo_info_header: SDOInfoHeader,
    index: u16,
    data_type: u16,
    max_subindex: u8,
    object_code: ObjectCode,
    name: []u8,
};

/// Value Info
///
/// What info about the value will be included in the response.
///
/// Ref: IEC 61158-6-12:2019 5.6.3.6.1
pub const ValueInfo = packed struct(u8) {
    reserved: u3 = 0,
    unit_type: bool,
    default_value: bool,
    minimum_value: bool,
    maximum_value: bool,
    reserved2: u1 = 0,
};

/// Get Entry Description Request
///
/// Ref: IEC 61158-6-12:2019 5.6.3.6.1
pub const GetEntryDescriptionRequest = packed struct {
    mbx_header: MailboxHeader,
    coe_header: CoEHeader,
    sdo_info_header: SDOInfoHeader,
    index: u16,
    subindex: u8,
    value_info: ValueInfo,

    pub fn init(
        cnt: u3,
        index: u16,
        subindex: u8,
        value_info: ValueInfo,
    ) GetEntryDescriptionRequest {
        assert(cnt != 0);
        return GetEntryDescriptionRequest{
            .mbx_header = .{
                .length = 10,
                .address = 0,
                .channel = 0,
                .priority = 0,
                .type = .CoE,
                .cnt = cnt,
            },
            .coe_header = .{
                .number = 0,
                .service = .sdo_info,
            },
            .sdo_info_header = .{
                .opcode = .get_entry_description_request,
                .incomplete = false,
                .fragments_left = 0,
            },
            .index = index,
            .subindex = subindex,
            .value_info = value_info,
        };
    }
};

/// Object Access
///
/// Ref: IEC 61158-6-12:2019 5.6.3.2
pub const ObjectAccess = packed struct(u16) {
    read_PREOP: bool,
    read_SAFEOP: bool,
    read_OP: bool,
    write_PREOP: bool,
    write_SAFEOP: bool,
    write_OP: bool,
    rxpdo_mappable: bool,
    txpdo_mappable: bool,
    backup: bool,
    setting: bool,
    reserved: u6 = 0,
};

/// Get Entry Description Response
///
/// Ref: IEC 61158-6-12:2019 5.6.3.2
pub const GetEntryDescriptionResponse = struct {
    mbx_header: MailboxHeader,
    coe_header: CoEHeader,
    sdo_info_header: SDOInfoHeader,
    index: u16,
    subindex: u8,
    value_info: ValueInfo,
    data_type: u16,
    bit_length: u16,
    object_access: ObjectAccess,
    data: []u8,
};

/// SDO Info Error Request
///
/// Ref: IEC 61158-6-12:2019 5.6.3.8
pub const SDOInfoErrorRequest = packed struct {
    mbx_header: MailboxHeader,
    coe_header: CoEHeader,
    sdo_info_header: SDOInfoHeader,
    abort_code: SDOAbortCode,
};

/// Emergency Request
///
/// Ref: IEC 61158-6-12:2019 5.6.4.1
pub const EmergencyRequest = packed struct {
    mbx_header: MailboxHeader,
    coe_header: CoEHeader,
    error_code: u16,
    error_register: u8,
    data: u40,
};

/// PDO Mailbox Transmission
///
/// Ref: IEC 61158-6-12:2019 5.6.5.1
/// Ref: IEC 61158-6-12:2019 5.6.5.1
pub const PDOTransmission = struct {
    mbx_header: MailboxHeader,
    coe_header: CoEHeader,
    data: []const u8,

    pub fn rx(
        cnt: u3,
        number: u9,
        data: []const u8,
    ) PDOTransmission {
        assert(cnt != 0);
        assert(data.len > 0);
        return PDOTransmission{
            .mbx_header = .{
                .length = @intCast(data.len + 2),
                .address = 0,
                .channel = 0,
                .priority = 0,
                .type = .CoE,
                .cnt = cnt,
            },
            .coe_header = .{
                .number = number,
                .service = .rx_pdo,
            },
            .data = data,
        };
    }

    pub fn tx(
        cnt: u3,
        number: u9,
        data: []const u8,
    ) PDOTransmission {
        assert(cnt != 0);
        assert(data.len > 0);
        return PDOTransmission{
            .mbx_header = .{
                .length = @intCast(data.len + 2),
                .address = 0,
                .channel = 0,
                .priority = 0,
                .type = .CoE,
                .cnt = cnt,
            },
            .coe_header = .{
                .number = number,
                .service = .tx_pdo,
            },
            .data = data,
        };
    }
};

/// PDO Remote Transmission Request
///
/// Ref: IEC 61158-6-12:2019 5.6.5.3
/// Ref: IEC 61158-6-12:2019 5.6.5.4
pub const PDORemoteTransmissionRequest = packed struct {
    mbx_header: MailboxHeader,
    coe_header: CoEHeader,

    pub fn rx(
        cnt: u3,
        number: u9,
    ) PDORemoteTransmissionRequest {
        assert(cnt != 0);
        return PDORemoteTransmissionRequest{
            .mbx_header = .{
                .length = 2,
                .address = 0,
                .channel = 0,
                .priority = 0,
                .type = .CoE,
                .cnt = cnt,
            },
            .coe_header = .{
                .number = number,
                .service = .rx_pdo_remote_request,
            },
        };
    }

    pub fn tx(
        cnt: u3,
        number: u9,
    ) PDORemoteTransmissionRequest {
        assert(cnt != 0);
        return PDORemoteTransmissionRequest{
            .mbx_header = .{
                .length = 2,
                .address = 0,
                .channel = 0,
                .priority = 0,
                .type = .CoE,
                .cnt = cnt,
            },
            .coe_header = .{
                .number = number,
                .service = .tx_pdo_remote_request,
            },
        };
    }
};

pub const CommandStatus = enum(u8) {
    completed_no_errors_no_reply = 0,
    completed_no_errors_reply = 1,
    complete_error_no_reply = 2,
    complete_error_reply = 3,
    executing = 255,
    _,
};

/// Command Object Structure
///
/// Each command shall have data type 0x0025.
///
/// Ref: IEC 61158-6-12:2019 5.6.6
pub const Command = struct {
    n_entries: u8,
    command: []u8,
    status: u8,
    reply: []u8,
};

/// The maximum mailbox size is limited by the maximum data that can be
/// read by a single datagram.
pub const max_mailbox_size = 1486;
comptime {
    assert(max_mailbox_size == telegram.max_frame_length - // 1514
        @divExact(@bitSizeOf(telegram.EthernetHeader), 8) - // u112
        @divExact(@bitSizeOf(telegram.EtherCATHeader), 8) - // u16
        @divExact(@bitSizeOf(telegram.DatagramHeader), 8) - // u80
        @divExact(@bitSizeOf(u16), 8)); // wkc
}

/// Send an Expedited SDO Read.
///
/// This is for data of length 1-4 bytes.
///
/// 1. Send sdo client expedited upload request until wkc = 1 or timeout
pub fn sdoReadExpedited(
    port: *nic.Port,
    station_address: u16,
    index: u16,
    subindex: u8,
    retries: u32,
    recv_timeout_us: u32,
    mbx_timeout_us: u32,
) !void {
    _ = mbx_timeout_us;
    _ = index;
    _ = subindex;

    // 1. send read

    // If mailbox in has got something in it, read mailbox to wipe it.
    const mbx_in: esc.SyncManagerAttributes = blk: {
        for (0..retries +% 1) |_| {
            const sm1_res = try commands.FPRD_ps(
                port,
                esc.SyncManagerAttributes,
                .{
                    .station_address = station_address,
                    .offset = @intFromEnum(esc.RegisterMap.SM1),
                },
                recv_timeout_us,
            );
            if (sm1_res.wkc == 1) {
                std.log.info("sm1 status: {}", .{sm1_res.ps.status});
                break :blk sm1_res.ps;
            }
        } else {
            return error.SubDeviceUnresponsive;
        }
        unreachable;
    };
    // mailbox configured?
    if (mbx_in.length == 0 or mbx_in.length > max_mailbox_size) {
        return error.InvalidMailboxConfiguration;
    }

    if (mbx_in.status.mailbox_full) {
        var buf = std.mem.zeroes([max_mailbox_size]u8); // yeet!
        for (0..retries +% 1) |_| {
            const wkc = try commands.FPRD(
                port,
                .{
                    .station_address = station_address,
                    .offset = mbx_in.physical_start_address,
                },
                &buf,
                recv_timeout_us,
            );
            if (wkc == 1) {
                break;
            }
        } else {
            return error.SubDeviceUnresponsive;
        }
    }

    const mbx_out: esc.SyncManagerAttributes = blk: {
        for (0..retries +% 1) |_| {
            const sm0_res = try commands.FPRD_ps(
                port,
                esc.SyncManagerAttributes,
                .{
                    .station_address = station_address,
                    .offset = @intFromEnum(esc.RegisterMap.SM0),
                },
                recv_timeout_us,
            );
            if (sm0_res.wkc == 1) {
                std.log.info("sm1 status: {}", .{sm0_res.ps.status});
                break :blk sm0_res.ps;
            }
        } else {
            return error.SubDeviceUnresponsive;
        }
        unreachable;
    };
    // mailbox configured?
    if (mbx_out.length == 0 or mbx_out.length > max_mailbox_size) {
        return error.InvalidMailboxConfiguration;
    }
}

pub fn readMailbox(
    port: *nic.Port,
    station_address: u16,
    retries: u32,
    recv_timeout_us: u32,
    mbx_timeout_us: u32,
) ![max_mailbox_size]u8 {
    _ = retries;
    var timer = try Timer.start();

    const mbx_in: esc.SyncManagerAttributes = blk: {
        while (timer.read() < mbx_timeout_us * ns_per_us) {
            const sm1_res = try commands.FPRD_ps(
                port,
                esc.SyncManagerAttributes,
                .{
                    .station_address = station_address,
                    .offset = @intFromEnum(esc.RegisterMap.SM1),
                },
                recv_timeout_us,
            );
            if (sm1_res.wkc == 1) {
                if (sm1_res.ps.status.mailbox_full) {
                    break :blk sm1_res.ps;
                }
            }
        } else {
            return error.Timeout;
        }
    };
    assert(mbx_in.status.mailbox_full);

    // mailbox configured?
    if (mbx_in.length == 0 or mbx_in.length > max_mailbox_size) {
        return error.InvalidMailboxConfiguration;
    }
}

pub const MailboxContentType = enum {
    sdo_download_expedited_or_normal_response,
    sdo_download_segment_response,

    sdo_upload_expedited_response,
    sdo_upload_normal_response,
    sdo_upload_segment_response,

    abort_sdo_transfer_request,

    get_od_list_response,
    get_object_description_response,
    get_entry_description_response,
    sdo_info_error,

    emergency_request,
};

// Messages that can be read from mailbox in.
//
// TODO: other mailbox protocols?
// pub const MailboxMessage = union(enum) {
//     sdo_download_expedited_request: SDODownloadExpeditedRequest,
//     sdo_download_expedited_response: SDODownloadExpeditedResponse,
//     // // sdo_download_normal_request: SDODownloadNormalRequest,
//     // sdo_download_normal_response: SDODownloadNormalResponse,
//     // sdo_download_segment_response: SDODownloadSegmentResponse,
//     // sdo_upload_expedited_response: SDOUploadExpeditedResponse,
//     // sdo_upload_normal_response: SDOUploadNormalResponse,
//     // sdo_upload_segment_response: SDOUploadSegmentResponse,
//     // abort_sdo_transfer_request: AbortSDOTransferRequest,
//     // get_od_list_response: GetODListResponse,
//     // get_object_description_response: GetObjectDescriptionResponse,
//     // get_entry_description_response: GetEntryDescriptionResponse,
//     // sdo_info_error_request: SDOInfoErrorRequest,
//     emergency_request: EmergencyRequest,
//     // rxpdo: RxPDOTransmission,
//     // txpdo: TxPDOTransmission,
//     // rxpdo_remote_request: RxPDORemoteTransmissionRequest,
//     // txpdo_remote_request: TxPDORemoteTransmissionRequest,

//     pub fn deserialize(buf: []const u8) !MailboxMessage {
//         var fbs = std.io.fixedBufferStream(buf);
//         var reader = fbs.reader();

//         const mbx_header = try nic.packFromECatReader(MailboxHeader, &reader);

//         if (mbx_header.length > buf.len - @divExact(@bitSizeOf(MailboxHeader), 8)) {
//             return error.InvalidMailboxHeaderLength;
//         }

//         switch (mbx_header.type) {
//             _ => return error.InvalidProtocol,
//             .ERR, .AoE, .EoE, .FoE, .SoE, .VoE => return error.UnsupportedMailboxProtocol,
//             .CoE => {
//                 const coe_header = try nic.packFromECatReader(CoEHeader, &reader);

//                 switch (coe_header.service) {
//                     _ => return error.InvalidService,
//                     .sdo_request => {
//                         const sdo_header = try nic.packFromECatReader(SDOHeaderClient, &reader);

//                         switch (sdo_header.command) {
//                             .download_request => {
//                                 switch (sdo_header.transfer_type) {
//                                     .expedited => {
//                                         fbs.reset();
//                                         const sdo_download_expedited_request = try nic.packFromECatReader(SDODownloadExpeditedRequest, &reader);
//                                         return MailboxMessage{ .sdo_download_expedited_request = sdo_download_expedited_request };
//                                     },
//                                     .normal => {
//                                         return error.NotImplemented;
//                                     },
//                                 }
//                             },
//                         }
//                     },
//                     // .sdo_response => {
//                     //     const sdo_header = try nic.packFromECatReader(SDOHeader, &reader);
//                     //     switch (sdo_header.command) {
//                     //         .download_response => {
//                     //             fbs.reset();
//                     //             const sdo_download_expedited_response = try nic.packFromECatReader(SDODownloadExpeditedResponse, &reader);
//                     //             return MailboxMessage{ .sdo_download_expedited_response = sdo_download_expedited_response };
//                     //         },
//                     //     }
//                     // },
//                     .emergency => {
//                         fbs.reset();
//                         const emergency_message = try nic.packFromECatReader(EmergencyRequest, &reader);
//                         return MailboxMessage{ .emergency_request = emergency_message };
//                     },
//                     .sdo_response => error.NotImplemented,
//                     .tx_pdo => return error.NotImplemented,
//                     .rx_pdo => return error.NotImplemented,
//                     .tx_pdo_remote_request => return error.NotImplemented,
//                     .rx_pdo_remote_request => return error.NotImplemented,
//                     .sdo_info => return error.NotImplemented,
//                 }
//             },
//         }
//         unreachable;
//     }
// };

// test "deserialize emergency message" {
//     const expected = EmergencyRequest{
//         .mbx_header = .{
//             .length = 10,
//             .address = 0x1001,
//             .channel = 0,
//             .priority = 0x03,
//             .type = .CoE,
//             .cnt = 3,
//         },
//         .coe_header = .{
//             .number = 0,
//             .service = .emergency,
//         },
//         .error_code = 0x1234,
//         .error_register = 23,
//         .data = 12345,
//     };
//     const buf = nic.eCatFromPack(expected);
//     var zero_buf = std.mem.zeroes([100]u8);
//     @memcpy(zero_buf[0..16], buf[0..16]);
//     const actual = try MailboxMessage.deserialize(&zero_buf);

//     try std.testing.expectEqualDeep(expected, actual.emergency_request);
// }

// test "deserialized sdo download expedited request" {
//     const expected = SDODownloadExpeditedRequest{
//         .mbx_header = .{
//             .length = 10,
//             .address = 0x1001,
//             .channel = 0,
//             .priority = 0x01,
//             .type = .CoE,
//             .cnt = 2,
//         },
//         .coe_header = .{
//             .number = 0,
//             .service = .sdo_request,
//         },
//         .sdo_header = .{
//             .size_indicator = true,
//             .transfer_type = .expedited,
//             .data_set_size = .one_octet,
//             .complete_access = false,
//             .command = .download_request,
//             .index = 0x6000,
//             .subindex = 34,
//         },
//         .data = @bitCast([4]u8{ 1, 2, 3, 4 }),
//     };
//     const buf = nic.eCatFromPack(expected);
//     var zero_buf = std.mem.zeroes([100]u8);
//     @memcpy(zero_buf[0..16], buf[0..16]);
//     const actual = try MailboxMessage.deserialize(&zero_buf);

//     try std.testing.expectEqualDeep(expected, actual.sdo_download_expedited_request);
// }

// fn deserializeMailboxData()

// fn readMailbox(port: *nic.Port) !void {
//     var buf = std.mem.zeroes([1486]u8); // yeet!
//     // read raw mailbox data into the buffer
//     read(port, &buf);
//     _ = deserializeMialboxData(&buf);
// }
