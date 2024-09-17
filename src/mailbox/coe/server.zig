const std = @import("std");
const assert = std.debug.assert;

const coe = @import("../coe.zig");
const mailbox = @import("../../mailbox.zig");
const wire = @import("../../wire.zig");

/// Server Command Specifier
///
/// See Client Command Specifier.
pub const CommandSpecifier = enum(u3) {
    upload_segment_response = 0,
    download_segment_response = 1,
    initiate_upload_response = 2,
    initiate_download_response = 3,
    abort_transfer_request = 4,
    // block_download = 5,
    // block_upload = 6,
    _,
};

/// SDO Header for CoE for subdevice to maindevice (server to client)
/// messages.
///
/// Ref: IEC 61158-6-12
pub const SDOHeader = packed struct(u32) {
    size_indicator: bool,
    transfer_type: coe.TransferType,
    data_set_size: coe.DataSetSize,
    /// false: entry addressed with index and subindex will be downloaded.
    /// true: complete object will be downlaoded. subindex shall be zero (when subindex zero
    /// is to be included) or one (subindex 0 excluded)
    complete_access: bool,
    command: CommandSpecifier,
    index: u16,
    /// shall be zero or one if complete access is true.
    subindex: u8,

    pub fn getDataSize(self: SDOHeader) usize {
        return switch (self.data_set_size) {
            .four_octets => 4,
            .three_octets => 3,
            .two_octets => 2,
            .one_octet => 1,
        };
    }
};

/// SDO Segment Header Server
///
/// Client / server language is from CANopen.
///
/// Ref: IEC 61158-6-12:2019 5.6.2.3.1
pub const SDOSegmentHeaderServer = packed struct {
    more_follows: bool,
    seg_data_size: coe.SegmentDataSize,
    /// shall toggle with every segment, starting with 0x00
    toggle: bool,
    command: CommandSpecifier,
};

/// SDO Expedited Responses
///
/// The coding for the SDO Download Normal Response is the same
/// as the SDO Download Expedited Response.
///
/// Ref: IEC 61158-6-12:2019 5.6.2.1.2 (SDO Download Expedited Response)
/// Ref: IEC 61158-6-12:2019 5.6.2.2.2 (SDO Download Normal Response)
/// Ref: IEC 61158-6-12:2019 5.6.2.4.2 (SDO Upload Expedited Response)
pub const Expedited = struct {
    mbx_header: mailbox.Header,
    coe_header: coe.Header,
    sdo_header: SDOHeader,
    data: std.BoundedArray(u8, 4),

    pub fn initDownloadResponse(
        cnt: u3,
        station_address: u16,
        index: u16,
        subindex: u8,
    ) Expedited {
        assert(cnt != 0);
        return Expedited{
            .mbx_header = .{
                .length = 10,
                .address = station_address,
                .channel = 0,
                .priority = 0,
                .type = .CoE,
                .cnt = cnt,
            },
            .coe_header = .{
                .number = 0,
                .service = .sdo_response,
            },
            .sdo_header = .{
                .size_indicator = false,
                .transfer_type = .normal,
                .data_set_size = .four_octets,
                .complete_access = false,
                .command = .initiate_download_response,
                .index = index,
                .subindex = subindex,
            },
            .data = std.BoundedArray(u8, 4).fromSlice(&.{ 0, 0, 0, 0 }) catch unreachable,
        };
    }

    pub fn initUploadResponse(
        cnt: u3,
        station_address: u16,
        index: u16,
        subindex: u8,
        data: []const u8,
    ) Expedited {
        assert(data.len > 0);
        assert(data.len < 5);
        assert(cnt != 0);

        const data_set_size: coe.DataSetSize = switch (data.len) {
            0 => unreachable,
            1 => .one_octet,
            2 => .two_octets,
            3 => .three_octets,
            4 => .four_octets,
            else => unreachable,
        };

        return Expedited{
            .mbx_header = .{
                .length = 10,
                .address = station_address,
                .channel = 0,
                .priority = 0,
                .type = .CoE,
                .cnt = cnt,
            },
            .coe_header = .{
                .number = 0,
                .service = .sdo_response,
            },
            .sdo_header = .{
                .size_indicator = true,
                .transfer_type = .expedited,
                .data_set_size = data_set_size,
                .complete_access = false,
                .command = .initiate_upload_response,
                .index = index,
                .subindex = subindex,
            },
            // data length already asserted
            .data = std.BoundedArray(u8, 4).fromSlice(data) catch unreachable,
        };
    }

    pub fn deserialize(buf: []const u8) !Expedited {
        var fbs = std.io.fixedBufferStream(buf);
        const reader = fbs.reader();
        const mbx_header = try wire.packFromECatReader(mailbox.Header, reader);
        const coe_header = try wire.packFromECatReader(coe.Header, reader);
        const sdo_header = try wire.packFromECatReader(SDOHeader, reader);
        const data_size: usize = sdo_header.getDataSize();
        var data = try std.BoundedArray(u8, 4).init(data_size);
        try reader.readNoEof(data.slice());

        return Expedited{
            .mbx_header = mbx_header,
            .coe_header = coe_header,
            .sdo_header = sdo_header,
            .data = data,
        };
    }

    pub fn serialize(self: Expedited, out: []u8) !usize {
        var fbs = std.io.fixedBufferStream(out);
        const writer = fbs.writer();
        try wire.eCatFromPackToWriter(self.mbx_header, writer);
        try wire.eCatFromPackToWriter(self.coe_header, writer);
        try wire.eCatFromPackToWriter(self.sdo_header, writer);
        try writer.writeAll(self.data.slice());
        return fbs.getWritten().len;
    }
};

test "SDO Server Expedited Serialize Deserialize" {
    const expected = Expedited.initDownloadResponse(
        3,
        234,
        23,
        4,
    );

    var bytes = std.mem.zeroes([mailbox.max_size]u8);
    const byte_size = try expected.serialize(&bytes);
    try std.testing.expectEqual(@as(usize, 6 + 2 + 8), byte_size);
    const actual = try Expedited.deserialize(&bytes);
    try std.testing.expectEqualDeep(expected, actual);
}

/// SDO Normal Reponses
///
/// Ref: IEC 61158-6-12:2019 5.6.2.5.2 (SDO Upload Normal Response)
pub const Normal = struct {
    mbx_header: mailbox.Header,
    coe_header: coe.Header,
    sdo_header: SDOHeader,
    complete_size: u32,
    data: std.BoundedArray(u8, data_max_size),

    pub const data_max_size = mailbox.max_size - 16;

    pub fn initUploadResponse(
        cnt: u3,
        station_address: u16,
        index: u16,
        subindex: u8,
        complete_size: u32,
        data: []const u8,
    ) Normal {
        assert(cnt != 0);
        assert(data.len < data_max_size);

        return Normal{
            .mbx_header = .{
                .length = @as(u16, @intCast(data.len)) + 10,
                .address = station_address,
                .channel = 0,
                .priority = 0,
                .type = .CoE,
                .cnt = cnt,
            },
            .coe_header = .{
                .number = 0,
                .service = .sdo_response,
            },
            .sdo_header = .{
                .size_indicator = true,
                .transfer_type = .normal,
                .data_set_size = @enumFromInt(0),
                .complete_access = false,
                .command = .upload_segment_response,
                .index = index,
                .subindex = subindex,
            },
            .complete_size = complete_size,
            .data = std.BoundedArray(u8, data_max_size).fromSlice(data) catch unreachable,
        };
    }

    pub fn deserialize(buf: []const u8) !Normal {
        var fbs = std.io.fixedBufferStream(buf);
        const reader = fbs.reader();
        const mbx_header = try wire.packFromECatReader(mailbox.Header, reader);
        const coe_header = try wire.packFromECatReader(coe.Header, reader);
        const sdo_header = try wire.packFromECatReader(SDOHeader, reader);
        const complete_size = try wire.packFromECatReader(u32, reader);

        if (mbx_header.length < 10) return error.InvalidMbxContent;

        const data_length: u16 = mbx_header.length -| 10;
        var data = try std.BoundedArray(u8, data_max_size).init(data_length);
        try reader.readNoEof(data.slice());

        return Normal{
            .mbx_header = mbx_header,
            .coe_header = coe_header,
            .sdo_header = sdo_header,
            .complete_size = complete_size,
            .data = data,
        };
    }

    pub fn serialize(self: *const Normal, out: []u8) !usize {
        var fbs = std.io.fixedBufferStream(out);
        const writer = fbs.writer();
        try wire.eCatFromPackToWriter(self.mbx_header, writer);
        try wire.eCatFromPackToWriter(self.coe_header, writer);
        try wire.eCatFromPackToWriter(self.sdo_header, writer);
        try wire.eCatFromPackToWriter(self.complete_size, writer);
        try writer.writeAll(self.data.slice());
        return fbs.getWritten().len;
    }

    comptime {
        assert(data_max_size == mailbox.max_size -
            @divExact(@bitSizeOf(mailbox.Header), 8) -
            @divExact(@bitSizeOf(coe.Header), 8) -
            @divExact(@bitSizeOf(SDOHeader), 8) -
            @divExact(@bitSizeOf(u32), 8));
    }
};

test "serialize and deserialize sdo server normal" {
    const expected = Normal.initUploadResponse(
        2,
        0,
        1234,
        12,
        2345,
        &.{ 1, 2, 3, 4 },
    );
    var bytes = std.mem.zeroes([mailbox.max_size]u8);
    const byte_size = try expected.serialize(&bytes);
    try std.testing.expectEqual(@as(usize, 6 + 2 + 12), byte_size);
    const actual = try Normal.deserialize(&bytes);
    try std.testing.expectEqualDeep(expected, actual);
}

/// SDO Segment Responses
///
/// Ref: IEC 61158-6-12:2019 5.6.2.3.2 (SDO Download Segment Reponse)
/// Ref: Ref: IEC 61158-6-12:2019 5.6.2.6.2 (SDO Upload Segment Response)
pub const Segment = struct {
    mbx_header: mailbox.Header,
    coe_header: coe.Header,
    seg_header: SDOSegmentHeaderServer,
    data: std.BoundedArray(u8, data_max_size),

    const data_max_size = mailbox.max_size - 9;

    pub fn initDownloadResponse(
        cnt: u3,
        station_address: u16,
        toggle: bool,
    ) Segment {
        assert(cnt != 0);

        return Segment{
            .mbx_header = .{
                .length = 10,
                .address = station_address,
                .channel = 0,
                .priority = 0,
                .type = .CoE,
                .cnt = cnt,
            },
            .coe_header = .{
                .number = 0,
                .service = .sdo_response,
            },
            .seg_header = .{
                .more_follows = false,
                .seg_data_size = @enumFromInt(0),

                .toggle = toggle,
                .command = .download_segment_response,
            },
            .data = std.BoundedArray(
                u8,
                data_max_size,
            ).fromSlice(
                &.{ 0, 0, 0, 0, 0, 0, 0 },
            ) catch unreachable,
        };
    }

    pub fn initUploadResponse(
        cnt: u3,
        station_address: u16,
        more_follows: bool,
        toggle: bool,
        data: []const u8,
    ) Segment {
        assert(cnt != 0);
        assert(data.len < data_max_size);

        const length = @max(10, @as(u16, @intCast(data.len + 3)));
        const padding_length: usize = @min(7, data.len -| 7);
        assert(padding_length <= 7);

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

        var temp_data = std.BoundedArray(
            u8,
            data_max_size,
        ).fromSlice(data) catch unreachable;
        temp_data.appendNTimes(@as(u8, 0), padding_length) catch unreachable;
        assert(temp_data.len >= 7);

        return Segment{
            .mbx_header = .{
                .length = length,
                .address = station_address,
                .channel = 0,
                .priority = 0,
                .type = .CoE,
                .cnt = cnt,
            },
            .coe_header = .{
                .number = 0,
                .service = .sdo_response,
            },
            .seg_header = .{
                .more_follows = more_follows,
                .seg_data_size = seg_data_size,
                .toggle = toggle,
                .command = .upload_segment_response,
            },
            .data = temp_data,
        };
    }

    pub fn deserialize(buf: []const u8) !Segment {
        var fbs = std.io.fixedBufferStream(buf);
        const reader = fbs.reader();
        const mbx_header = try wire.packFromECatReader(mailbox.Header, reader);
        const coe_header = try wire.packFromECatReader(coe.Header, reader);
        const seg_header = try wire.packFromECatReader(SDOSegmentHeaderServer, reader);

        var data_size: usize = 0;
        if (mbx_header.length < 10) {
            return error.InvalidMbxContent;
        } else if (mbx_header.length == 10) {
            data_size = switch (seg_header.seg_data_size) {
                .zero_octets => 0,
                .one_octet => 1,
                .two_octets => 2,
                .three_octets => 3,
                .four_octets => 4,
                .five_octets => 5,
                .six_octets => 6,
                .seven_octets => 7,
            };
        } else {
            assert(mbx_header.length > 10);
            data_size = mbx_header.length - 3;
            assert(data_size == mbx_header.length -
                @divExact(@bitSizeOf(coe.Header), 8) -
                @divExact(@bitSizeOf(SDOSegmentHeaderServer), 8));
        }
        var data = try std.BoundedArray(u8, data_max_size).init(data_size);
        try reader.readNoEof(data.slice());

        return Segment{
            .mbx_header = mbx_header,
            .coe_header = coe_header,
            .seg_header = seg_header,
            .data = data,
        };
    }

    pub fn serialize(self: *const Segment, out: []u8) !usize {
        var fbs = std.io.fixedBufferStream(out);
        const writer = fbs.writer();
        try wire.eCatFromPackToWriter(self.mbx_header, writer);
        try wire.eCatFromPackToWriter(self.coe_header, writer);
        try wire.eCatFromPackToWriter(self.seg_header, writer);
        try writer.writeAll(self.data.slice());
        return fbs.getWritten().len;
    }

    comptime {
        assert(data_max_size == mailbox.max_size -
            @divExact(@bitSizeOf(mailbox.Header), 8) -
            @divExact(@bitSizeOf(coe.Header), 8) -
            @divExact(@bitSizeOf(SDOSegmentHeaderServer), 8));
        assert(data_max_size >= 7);
    }
};

test "serialize and deserialize sdo server segment" {
    const expected = Segment.initUploadResponse(
        2,
        0,
        false,
        false,
        &.{ 1, 2, 3, 4 },
    );
    var bytes = std.mem.zeroes([mailbox.max_size]u8);
    const byte_size = try expected.serialize(&bytes);
    try std.testing.expectEqual(@as(usize, 6 + 2 + 5), byte_size);
    const actual = try Segment.deserialize(&bytes);
    try std.testing.expectEqualDeep(expected, actual);
}

/// SDO Abort Codes
///
/// Ref: IEC 61158-6-12:2019 5.6.2.7.2
pub const SDOAbortCode = enum(u32) {
    ToggleBitNotChanged = 0x05_03_00_00,
    SdoProtocolTimeout = 0x05_04_00_00,
    CommandSpecifierNotValidOrUnknown = 0x05_04_00_01,
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
pub const Abort = packed struct(u128) {
    mbx_header: mailbox.Header,
    coe_header: coe.Header,
    sdo_header: SDOHeader,
    abort_code: SDOAbortCode,

    pub fn init(
        cnt: u3,
        station_address: u16,
        index: u16,
        subindex: u8,
        abort_code: SDOAbortCode,
    ) Abort {
        assert(cnt != 0);

        return Abort{
            .mbx_header = .{
                .length = 10,
                .address = station_address,
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
                .size_indicator = false,
                .transfer_type = @enumFromInt(0),
                .data_set_size = @enumFromInt(0),
                .complete_access = false,
                .command = .abort_transfer_request,
                .index = index,
                .subindex = subindex,
            },
            .abort_code = abort_code,
        };
    }

    pub fn deserialize(buf: []const u8) !Abort {
        var fbs = std.io.fixedBufferStream(buf);
        const reader = fbs.reader();
        return try wire.packFromECatReader(Abort, reader);
    }

    pub fn serialize(self: Abort, out: []u8) !usize {
        var fbs = std.io.fixedBufferStream(out);
        const writer = fbs.writer();
        try wire.eCatFromPackToWriter(self, writer);
        return fbs.getWritten().len;
    }
};

test "serialize and deserialize abort sdo transfer request" {
    const expected = Abort.init(
        3,
        345,
        345,
        3,
        .AccessFailedDueToHardwareError,
    );
    var bytes = std.mem.zeroes([mailbox.max_size]u8);
    const byte_size = try expected.serialize(&bytes);
    try std.testing.expectEqual(@as(usize, 6 + 2 + 8), byte_size);
    const actual = try Abort.deserialize(&bytes);
    try std.testing.expectEqualDeep(expected, actual);
}

/// Get OD List Response
///
/// Ref: IEC 61158-6-12:2019 5.6.3.3.2
pub const GetODListResponse = struct {
    mbx_header: mailbox.Header,
    coe_header: coe.Header,
    sdo_info_header: coe.SDOInfoHeader,
    list_type: coe.ODListType,
    index_list: []u16,
};

/// Get Object Description Response
///
/// Ref: IEC 61158-6-12:2019 5.6.3.5.2
pub const GetObjectDescriptionResponse = struct {
    mbx_header: mailbox.Header,
    coe_header: coe.Header,
    sdo_info_header: coe.SDOInfoHeader,
    index: u16,
    data_type: u16,
    max_subindex: u8,
    object_code: coe.ObjectCode,
    name: []u8,
};

/// Get Entry Description Response
///
/// Ref: IEC 61158-6-12:2019 5.6.3.2
pub const GetEntryDescriptionResponse = struct {
    mbx_header: mailbox.Header,
    coe_header: coe.Header,
    sdo_info_header: coe.SDOInfoHeader,
    index: u16,
    subindex: u8,
    value_info: coe.ValueInfo,
    data_type: u16,
    bit_length: u16,
    object_access: coe.ObjectAccess,
    data: []u8,
};

/// SDO Info Error Request
///
/// Ref: IEC 61158-6-12:2019 5.6.3.8
pub const SDOInfoErrorRequest = packed struct {
    mbx_header: mailbox.Header,
    coe_header: coe.Header,
    sdo_info_header: coe.SDOInfoHeader,
    abort_code: SDOAbortCode,
};

/// Emergency Request
///
/// Ref: IEC 61158-6-12:2019 5.6.4.1
pub const Emergency = packed struct(u128) {
    mbx_header: mailbox.Header,
    coe_header: coe.Header,
    error_code: u16,
    error_register: u8,
    data: u40,

    pub fn init(
        cnt: u3,
        station_address: u16,
        error_code: u16,
        error_register: u8,
        data: u40,
    ) Emergency {
        return Emergency{
            .mbx_header = .{
                .length = 10,
                .address = station_address,
                .channel = 0,
                .priority = 0,
                .type = .CoE,
                .cnt = cnt,
            },
            .coe_header = .{
                .number = 0,
                .service = .emergency,
            },
            .error_code = error_code,
            .error_register = error_register,
            .data = data,
        };
    }

    pub fn deserialize(buf: []const u8) !Emergency {
        var fbs = std.io.fixedBufferStream(buf);
        const reader = fbs.reader();
        return try wire.packFromECatReader(Emergency, reader);
    }

    pub fn serialize(self: Emergency, out: []u8) !usize {
        var fbs = std.io.fixedBufferStream(out);
        const writer = fbs.writer();
        try wire.eCatFromPackToWriter(self, writer);
        return fbs.getWritten().len;
    }
};

test "serialize and deserialize emergency request" {
    const expected = Emergency.init(
        4,
        234,
        2366,
        23,
        3425654,
    );
    var bytes = std.mem.zeroes([mailbox.max_size]u8);
    const byte_size = try expected.serialize(&bytes);
    try std.testing.expectEqual(@as(usize, 6 + 2 + 8), byte_size);
    const actual = try Emergency.deserialize(&bytes);
    try std.testing.expectEqualDeep(expected, actual);
}
