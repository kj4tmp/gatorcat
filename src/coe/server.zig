const std = @import("std");
const assert = std.debug.assert;

const nic = @import("../nic.zig");
const coe = @import("coe.zig");
const mailbox = @import("../mailbox.zig");

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

/// SDO Header for CoE for subdevice to maindevice (server to client)
/// messages.
///
/// Ref: IEC 61158-6-12
pub const SDOHeaderServer = packed struct(u32) {
    size_indicator: bool,
    transfer_type: coe.TransferType,
    data_set_size: coe.DataSetSize,
    /// false: entry addressed with index and subindex will be downloaded.
    /// true: complete object will be downlaoded. subindex shall be zero (when subindex zero
    /// is to be included) or one (subindex 0 excluded)
    complete_access: bool,
    command: ServerCommandSpecifier,
    index: u16,
    /// shall be zero or one if complete access is true.
    subindex: u8,
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
    command: ServerCommandSpecifier,
};

/// SDO Expedited Responses
///
/// The coding for the SDO Download Normal Response is the same
/// as the SDO Download Expedited Response.
///
/// Ref: IEC 61158-6-12:2019 5.6.2.1.2 (SDO Download Expedited Response)
/// Ref: IEC 61158-6-12:2019 5.6.2.2.2 (SDO Download Normal Response)
/// Ref: IEC 61158-6-12:2019 5.6.2.4.2 (SDO Upload Expedited Response)
pub const SDOServerExpedited = packed struct(u128) {
    mbx_header: mailbox.MailboxHeader,
    coe_header: coe.CoEHeader,
    sdo_header: SDOHeaderServer,
    data: std.BoundedArray(u8, 4) = 0,

    pub fn initDownloadResponse(
        cnt: u3,
        station_address: u16,
        index: u16,
        subindex: u8,
    ) SDOServerExpedited {
        return SDOServerExpedited{
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
            .data = std.BoundedArray(u8, 4).fromSlice(&.{ 0, 0, 0, 0 }),
        };
    }

    pub fn initUploadResponse(
        cnt: u3,
        station_address: u16,
        index: u16,
        subindex: u8,
        data: std.BoundedArray(u8, 4),
    ) SDOServerExpedited {
        assert(data.len > 0);

        const data_set_size: coe.DataSetSize = switch (data.len) {
            0 => unreachable,
            1 => .one_octet,
            2 => .two_octets,
            3 => .three_octets,
            4 => .four_octets,
            else => unreachable,
        };

        return SDOServerExpedited{
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
            .data = data,
        };
    }

    pub fn deserialize(buf: []const u8) !SDOServerExpedited {
        var fbs = std.io.fixedBufferStream(buf);
        var reader = fbs.reader();
        const mbx_header = try nic.packFromECatReader(mailbox.MailboxHeader, reader);
        const coe_header = try nic.packFromECatReader(coe.CoEHeader, reader);
        const sdo_header = try nic.packFromECatReader(SDOHeaderServer, reader);
        const data_size: usize = switch (sdo_header.data_set_size) {
            .one_octet => 1,
            .two_octets => 2,
            .three_octets => 3,
            .four_octets => 4,
        };
        var data = try std.BoundedArray(u8, 4).init(data_size);
        try reader.readNoEof(data.slice());

        return SDOServerExpedited{
            .mbx_header = mbx_header,
            .coe_header = coe_header,
            .sdo_header = sdo_header,
            .data = data,
        };
    }

    pub fn serialize(self: SDOServerExpedited, out: []u8) !usize {
        var fbs = std.io.fixedBufferStream(out);
        const writer = fbs.writer();
        try nic.eCatFromPackToWriter(self, writer);
        return fbs.getWritten().len;
    }
};

/// SDO Normal Reponses
///
/// Ref: IEC 61158-6-12:2019 5.6.2.5.2 (SDO Upload Normal Response)
pub const SDOServerNormal = struct {
    mbx_header: mailbox.MailboxHeader,
    coe_header: coe.CoEHeader,
    sdo_header: SDOHeaderServer,
    complete_size: u32,
    data: std.BoundedArray(u8, data_max_size),

    pub const data_max_size = mailbox.max_size - 16;

    pub fn deserialize(buf: []const u8) !SDOServerNormal {
        var fbs = std.io.fixedBufferStream(buf);
        const reader = fbs.reader();
        const mbx_header = try nic.packFromECatReader(mailbox.MailboxHeader, reader);
        const coe_header = try nic.packFromECatReader(coe.CoEHeader, reader);
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
        assert(data_max_size == mailbox.max_size -
            @divExact(@bitSizeOf(mailbox.MailboxHeader), 8) -
            @divExact(@bitSizeOf(coe.CoEHeader), 8) -
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
    var bytes = std.mem.zeroes([mailbox.max_size]u8);
    const byte_size = try expected.serialize(&bytes);
    try std.testing.expectEqual(@as(usize, 6 + 2 + 12), byte_size);
    const actual = try SDOServerNormal.deserialize(&bytes);
    try std.testing.expectEqualDeep(expected, actual);
}

/// SDO Segment Responses
///
/// Ref: IEC 61158-6-12:2019 5.6.2.3.2 (SDO Download Segment Reponse)
/// Ref: Ref: IEC 61158-6-12:2019 5.6.2.6.2 (SDO Upload Segment Response)
pub const SDOServerSegment = struct {
    mbx_header: mailbox.MailboxHeader,
    coe_header: coe.CoEHeader,
    seg_header: SDOSegmentHeaderServer,
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
    mbx_header: mailbox.MailboxHeader,
    coe_header: coe.CoEHeader,
    /// SDOHeaderServer is arbitrarily chosen here.
    /// Abort has no concept of client / server.
    sdo_header: SDOHeaderServer,
    abort_code: SDOAbortCode,
};

/// Get OD List Response
///
/// Ref: IEC 61158-6-12:2019 5.6.3.3.2
pub const GetODListResponse = struct {
    mbx_header: mailbox.MailboxHeader,
    coe_header: coe.CoEHeader,
    sdo_info_header: coe.SDOInfoHeader,
    list_type: coe.ODListType,
    index_list: []u16,
};

/// Get Object Description Response
///
/// Ref: IEC 61158-6-12:2019 5.6.3.5.2
pub const GetObjectDescriptionResponse = struct {
    mbx_header: mailbox.MailboxHeader,
    coe_header: coe.CoEHeader,
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
    mbx_header: mailbox.MailboxHeader,
    coe_header: coe.CoEHeader,
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
    mbx_header: mailbox.MailboxHeader,
    coe_header: coe.CoEHeader,
    sdo_info_header: coe.SDOInfoHeader,
    abort_code: SDOAbortCode,
};

/// Emergency Request
///
/// Ref: IEC 61158-6-12:2019 5.6.4.1
pub const EmergencyRequest = packed struct {
    mbx_header: mailbox.MailboxHeader,
    coe_header: coe.CoEHeader,
    error_code: u16,
    error_register: u8,
    data: u40,
};
