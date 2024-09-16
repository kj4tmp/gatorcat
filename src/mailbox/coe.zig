const std = @import("std");
const Timer = std.time.Timer;
const ns_per_us = std.time.ns_per_us;
const assert = std.debug.assert;

const mailbox = @import("../mailbox.zig");
const wire = @import("../wire.zig");
const nic = @import("../nic.zig");

pub const server = @import("coe/server.zig");
pub const client = @import("coe/client.zig");

// TODO: support more than expedited reads
pub fn sdoRead(
    port: *nic.Port,
    station_address: u16,
    index: u16,
    subindex: u8,
    comptime packed_type: type,
    recv_timeout_us: u32,
    mbx_timeout_us: u32,
    cnt: u3,
    mbx_in_start_addr: u16,
    mbx_in_length: u16,
    mbx_out_start_addr: u16,
    mbx_out_length: u16,
) !packed_type {
    comptime assert(wire.packedSize(packed_type) > 0);
    comptime assert(wire.packedSize(packed_type) < 5);

    assert(cnt != 0);
    assert(mbx_in_length > 0);
    assert(mbx_in_length <= mailbox.max_size);
    assert(mbx_out_length > 0);
    assert(mbx_out_length <= mailbox.max_size);

    const request = mailbox.OutContent{
        .coe = OutContent{
            .expedited = client.Expedited.initUploadRequest(
                cnt,
                index,
                subindex,
            ),
        },
    };
    try mailbox.writeMailboxOut(
        port,
        station_address,
        recv_timeout_us,
        mbx_out_start_addr,
        mbx_out_length,
        request,
    );

    var timer = Timer.start() catch unreachable;

    while (timer.read() < mbx_timeout_us * ns_per_us) {
        const response = mailbox.readMailboxIn(
            port,
            station_address,
            recv_timeout_us,
            mbx_in_start_addr,
            mbx_in_length,
        ) catch |err| {
            switch (err) {
                error.LinkError => return error.LinkError,
                error.TransactionContention => continue,
                error.RecvTimeout => continue,
                error.CurruptedFrame => continue,
                error.Wkc => continue,
                error.Empty => continue,
                error.InvalidMbxContent => return error.InvalidMbxContent,
                error.NotImplemented => return error.NotImplemented,
                error.InvalidMbxConfiguration => return error.InvalidMbxConfiguration,
            }
        };
        // TODO: handle emergency messages
        // TODO: handle eoe?

        if (response != .coe) {
            return error.WrongProtocol;
        }

        if (response.coe != .expedited) {
            return error.WrongResponse;
        }
        const data = response.coe.expedited.data;
        // TODO: add a reader() method to boundedArray in standard library

        var fbs = std.io.fixedBufferStream(data.slice());
        const reader = fbs.reader();
        std.log.warn("time req: {}us", .{timer.read() / ns_per_us});
        return wire.packFromECatReader(packed_type, reader) catch error.InvalidResponseDataLength;
    } else return error.MbxTimeout;
}

/// MailboxOut Content for CoE
pub const OutContent = union(enum) {
    expedited: client.Expedited,
    normal: client.Normal,
    segment: client.Segment,
    abort: client.Abort,

    // TODO: implement remaining CoE content types

    pub fn serialize(self: OutContent, out: []u8) !usize {
        switch (self) {
            .expedited => return self.expedited.serialize(out),
            .normal => return self.normal.serialize(out),
            .segment => return self.segment.serialize(out),
            .abort => return self.abort.serialize(out),
        }
    }
};

/// MailboxIn Content for CoE.
pub const InContent = union(enum) {
    expedited: server.Expedited,
    normal: server.Normal,
    segment: server.Segment,
    abort: server.Abort,
    emergency: server.Emergency,

    // TODO: implement remaining CoE content types

    pub fn deserialize(buf: []const u8) !InContent {
        switch (try identify(buf)) {
            .expedited => return InContent{ .expedited = try server.Expedited.deserialize(buf) },
            .normal => return InContent{ .normal = try server.Normal.deserialize(buf) },
            .segment => return InContent{ .segment = try server.Segment.deserialize(buf) },
            .abort => return InContent{ .abort = try server.Abort.deserialize(buf) },
            .emergency => return InContent{ .emergency = try server.Emergency.deserialize(buf) },
        }
    }

    /// Identify what kind of CoE content is in MailboxIn
    fn identify(buf: []const u8) !std.meta.Tag(InContent) {
        var fbs = std.io.fixedBufferStream(buf);
        const reader = fbs.reader();
        const mbx_header = try wire.packFromECatReader(mailbox.Header, reader);

        switch (mbx_header.type) {
            .CoE => {},
            else => return error.WrongMbxProtocol,
        }
        const header = try wire.packFromECatReader(Header, reader);

        switch (header.service) {
            .tx_pdo => return error.NotImplemented,
            .rx_pdo => return error.NotImplemented,
            .tx_pdo_remote_request => return error.NotImplemented,
            .rx_pdo_remote_request => return error.NotImplemented,
            .sdo_info => return error.NotImplemented,

            .sdo_request => {
                const sdo_header = try wire.packFromECatReader(server.SDOHeader, reader);
                return switch (sdo_header.command) {
                    .abort_transfer_request => .abort,
                    else => error.InvalidMbxContent,
                };
            },
            .sdo_response => {
                const sdo_header = try wire.packFromECatReader(server.SDOHeader, reader);
                switch (sdo_header.command) {
                    .upload_segment_response => return .segment,
                    .download_segment_response => return .segment,
                    .initiate_upload_response => switch (sdo_header.transfer_type) {
                        .normal => return .normal,
                        .expedited => return .expedited,
                    },
                    .initiate_download_response => return .expedited,
                    .abort_transfer_request => return .abort,
                    _ => return error.InvalidMbxContent,
                }
            },
            .emergency => return .emergency,
            _ => return error.InvalidMbxContent,
        }
    }
};

test "serialize deserialize mailbox in content" {
    const expected = InContent{
        .expedited = server.Expedited.initDownloadResponse(
            3,
            234,
            23,
            4,
        ),
    };

    var bytes = std.mem.zeroes([mailbox.max_size]u8);
    const byte_size = try expected.expedited.serialize(&bytes);
    try std.testing.expectEqual(@as(usize, 6 + 2 + 8), byte_size);
    const actual = try InContent.deserialize(&bytes);
    try std.testing.expectEqualDeep(expected, actual);
}

pub const DataSetSize = enum(u2) {
    four_octets = 0x00,
    three_octets = 0x01,
    two_octets = 0x02,
    one_octet = 0x03,
};

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

pub const Header = packed struct(u16) {
    number: u9 = 0,
    reserved: u3 = 0,
    service: Service,
};

pub const TransferType = enum(u1) {
    normal = 0x00,
    expedited = 0x01,
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

/// Object Code
///
/// Ref: IEC 61158-6-12:2019 5.6.3.5.2
pub const ObjectCode = enum(u8) {
    variable = 7,
    array = 8,
    record = 9,
    _,
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
