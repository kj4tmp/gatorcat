const std = @import("std");
const assert = std.debug.assert;

const nic = @import("../nic.zig");
const coe = @import("coe.zig");
const mailbox = @import("../mailbox.zig");

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

/// SDO Header for CoE for maindevice to subdevice (client to server)
/// messages.
///
/// Ref: IEC 61158-6-12
pub const SDOHeaderClient = packed struct(u32) {
    size_indicator: bool,
    transfer_type: coe.TransferType,
    data_set_size: coe.DataSetSize,
    /// false: entry addressed with index and subindex will be downloaded.
    /// true: complete object will be downlaoded. subindex shall be zero (when subindex zero
    /// is to be included) or one (subindex 0 excluded)
    complete_access: bool,
    command: ClientCommandSpecifier,
    index: u16,
    /// shall be zero or one if complete access is true.
    subindex: u8,
};

pub const SDOClientExpedited = packed struct(u128) {
    mbx_header: mailbox.MailboxHeader,
    coe_header: coe.CoEHeader,
    sdo_header: SDOHeaderClient,
    data: u32,

    /// Create an SDO Download Expedited Request
    ///
    /// data must be between 1 and 4 bytes long
    ///
    /// Ref: IEC 61158-6-12:2019 5.6.2.1.1
    pub fn initDownloadRequest(
        cnt: u3,
        index: u16,
        subindex: u8,
        data: [4]u8,
    ) SDOClientExpedited {
        assert(cnt != 0);
        const size: coe.DataSetSize = switch (data.len) {
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
    pub fn initUploadRequest(
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
    const expected = SDOClientExpedited.initDownloadRequest(
        5,
        1234,
        23,
        .{ 1, 2, 3, 4 },
    );

    var bytes = std.mem.zeroes([mailbox.max_size]u8);
    const byte_size = try expected.serialize(&bytes);
    try std.testing.expectEqual(@as(usize, 6 + 2 + 8), byte_size);
    const actual = try SDOClientExpedited.deserialize(&bytes);
    try std.testing.expectEqualDeep(expected, actual);
}

pub const SDOClientNormal = struct {
    mbx_header: mailbox.MailboxHeader,
    coe_header: coe.CoEHeader,
    sdo_header: SDOHeaderClient,
    complete_size: u32,
    data: std.BoundedArray(u8, data_max_size),

    pub const data_max_size = mailbox.max_size - 16;

    /// Create an SDO Download Normal Request
    ///
    /// Ref: IEC 61158-6-12:2019 5.6.2.2.1
    /// Ref: IEC 61158-6-12:2019 5.6.2.5.1
    pub fn initDownloadRequest(
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
        const mbx_header = try nic.packFromECatReader(mailbox.MailboxHeader, reader);
        const coe_header = try nic.packFromECatReader(coe.CoEHeader, reader);
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
            mailbox.max_size -
            @divExact(@bitSizeOf(mailbox.MailboxHeader), 8) -
            @divExact(@bitSizeOf(coe.CoEHeader), 8) -
            @divExact(@bitSizeOf(SDOHeaderClient), 8) -
            @divExact(@bitSizeOf(u32), 8));
    }
};

test "serialize deserialize SDO client normal" {
    const expected = try SDOClientNormal.initDownloadRequest(
        2,
        1000,
        23,
        12345,
        &.{ 1, 2, 3 },
    );

    var bytes = std.mem.zeroes([mailbox.max_size]u8);
    const byte_size = try expected.serialize(&bytes);
    try std.testing.expectEqual(@as(usize, 6 + 2 + 8 + 3), byte_size);
    const actual = try SDOClientNormal.deserialize(&bytes);
    try std.testing.expectEqualDeep(expected, actual);
}

///
pub const SDOClientSegment = struct {
    mbx_header: mailbox.MailboxHeader,
    coe_header: coe.CoEHeader,
    sdo_seg_header: SDOSegmentHeaderClient,
    data: std.BoundedArray(u8, data_max_size),

    pub const data_max_size = mailbox.max_size - 12;

    /// Create an SDO Download Segmented Request
    ///
    /// Ref: IEC 61158-6-12:2019 5.6.2.3.1
    pub fn initDownloadRequest(
        cnt: u3,
        more_follows: bool,
        toggle: bool,
        data: []const u8,
    ) !SDOClientSegment {
        assert(cnt != 0);
        const length = @max(10, @as(u16, @intCast(data.len + 3)));

        const seg_data_size: coe.SegmentDataSize = switch (data.len) {
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
    pub fn initUploadRequest(
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
        const mbx_header = try nic.packFromECatReader(mailbox.MailboxHeader, reader);
        const coe_header = try nic.packFromECatReader(coe.CoEHeader, reader);
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
            mailbox.max_size -
            @divExact(@bitSizeOf(mailbox.MailboxHeader), 8) -
            @divExact(@bitSizeOf(coe.CoEHeader), 8) -
            @divExact(@bitSizeOf(SDOHeaderClient), 8));
    }

    comptime {
        assert(data_max_size >= 7); // must be able to fit upload request
    }
};

test "serialize deserialize sdo client segment" {
    const expected = try SDOClientSegment.initDownloadRequest(
        3,
        true,
        true,
        &.{ 1, 2, 3, 4, 5, 6, 7 },
    );

    var bytes = std.mem.zeroes([mailbox.max_size]u8);
    const byte_size = try expected.serialize(&bytes);
    try std.testing.expectEqual(@as(usize, 6 + 2 + 8), byte_size);
    const actual = try SDOClientSegment.deserialize(&bytes);
    try std.testing.expectEqualDeep(expected, actual);
}

test "sdo client segment seg_data_size" {
    const actual = try SDOClientSegment.initDownloadRequest(
        3,
        true,
        true,
        &.{ 1, 2, 3, 4 },
    );
    try std.testing.expectEqual(coe.SegmentDataSize.four_octets, actual.sdo_seg_header.seg_data_size);
}

/// SDO Segment Header Client
///
/// Client / server language is from CANopen.
///
/// Ref: IEC 61158-6-12:2019 5.6.2.3.1
pub const SDOSegmentHeaderClient = packed struct {
    more_follows: bool,
    seg_data_size: coe.SegmentDataSize,
    /// shall toggle with every segment, starting with 0x00
    toggle: bool,
    command: ClientCommandSpecifier,
};

/// Get OD List Request
///
/// Ref: IEC 61158-6-12:2019 5.6.3.3.1
pub const GetODListRequest = packed struct {
    mbx_header: mailbox.MailboxHeader,
    coe_header: coe.CoEHeader,
    sdo_info_header: coe.SDOInfoHeader,
    list_type: coe.ODListType,

    pub fn init(
        cnt: u3,
        list_type: coe.ODListType,
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

/// Get Object Description Request
///
/// Ref: IEC 61158-6-12:2019 5.6.3.5.1
pub const GetObjectDescriptionRequest = packed struct {
    mbx_header: mailbox.MailboxHeader,
    coe_header: coe.CoEHeader,
    sdo_info_header: coe.SDOInfoHeader,
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

/// Get Entry Description Request
///
/// Ref: IEC 61158-6-12:2019 5.6.3.6.1
pub const GetEntryDescriptionRequest = packed struct {
    mbx_header: mailbox.MailboxHeader,
    coe_header: coe.CoEHeader,
    sdo_info_header: coe.SDOInfoHeader,
    index: u16,
    subindex: u8,
    value_info: coe.ValueInfo,

    pub fn init(
        cnt: u3,
        index: u16,
        subindex: u8,
        value_info: coe.ValueInfo,
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

/// PDO Mailbox Transmission
///
/// Ref: IEC 61158-6-12:2019 5.6.5.1
/// Ref: IEC 61158-6-12:2019 5.6.5.1
pub const PDOTransmission = struct {
    mbx_header: mailbox.MailboxHeader,
    coe_header: coe.CoEHeader,
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
    mbx_header: mailbox.MailboxHeader,
    coe_header: coe.CoEHeader,

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
