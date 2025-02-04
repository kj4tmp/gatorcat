// TODO: Reduce memory usage of the bounded arrays in this module.

const std = @import("std");
const Timer = std.time.Timer;
const ns_per_us = std.time.ns_per_us;
const assert = std.debug.assert;

const mailbox = @import("../mailbox.zig");
const nic = @import("../nic.zig");
const Port = @import("../Port.zig");
const sii = @import("../sii.zig");
const wire = @import("../wire.zig");
pub const client = @import("coe/client.zig");
pub const server = @import("coe/server.zig");

pub fn sdoWrite(
    port: *Port,
    station_address: u16,
    index: u16,
    subindex: u8,
    complete_access: bool,
    buf: []const u8,
    recv_timeout_us: u32,
    mbx_timeout_us: u32,
    cnt: u3,
    config: mailbox.Configuration,
    diag: ?*mailbox.InContent,
) !void {
    assert(cnt != 0);
    if (complete_access) {
        assert(subindex == 1 or subindex == 0);
    }
    assert(buf.len > 0);
    assert(buf.len <= std.math.maxInt(u32));
    assert(config.isValid());

    const State = enum {
        start,
        send_expedited_request,
        send_normal_request,
        // send_first_segment,
        read_mbx,
        // read_mbx_first_segment,
    };

    state: switch (State.start) {
        .start => {
            if (buf.len < 5) continue :state .send_expedited_request;

            if (buf.len <= client.Normal.dataMaxSizeForMailbox(config.mbx_out.length)) {
                continue :state .send_normal_request;
            } else {
                return error.NotImplemented;
                // continue :state .send_first_segment;
            }
        },
        .send_expedited_request => {
            assert(buf.len < 5);

            const out_content = OutContent{ .expedited = client.Expedited.initDownloadRequest(
                cnt,
                index,
                subindex,
                complete_access,
                buf,
            ) };

            try mailbox.writeMailboxOut(
                port,
                station_address,
                recv_timeout_us,
                config.mbx_out,
                .{ .coe = out_content },
            );
            continue :state .read_mbx;
        },
        .send_normal_request => {
            assert(buf.len > 4);
            assert(buf.len <= client.Normal.dataMaxSizeForMailbox(config.mbx_out.length));

            const out_content = OutContent{ .normal = client.Normal.initDownloadRequest(
                cnt,
                index,
                subindex,
                complete_access,
                @intCast(buf.len),
                buf,
            ) };

            try mailbox.writeMailboxOut(
                port,
                station_address,
                recv_timeout_us,
                config.mbx_out,
                .{ .coe = out_content },
            );
            continue :state .read_mbx;
        },
        // .send_first_segment => {
        // assert(buf.size > 4);
        // const max_segment_size = client.normal.dataMaxSizeForMailbox(mbx_out_length);
        // assert(buf.size > max_segment_size);
        // assert(fbs.getPos() catch unreachable == 0);

        // const out_content = OutContent{ .normal = client.Normal.initDownloadRequest(
        //     cnt,
        //     index,
        //     subindex,
        //     complete_access,
        //     buf.size,
        //     buf[fbs.getPos() catch unreachable .. max_segment_size],
        // ) };
        // try mailbox.writeMailboxOut(
        //     port,
        //     station_address,
        //     recv_timeout_us,
        //     mbx_out_start_addr,
        //     mbx_out_length,
        //     .{ .coe = out_content },
        // );

        // fbs.seekBy(max_segment_size) catch unreachable;

        // continue :state .read_mbx_first_segment;
        // },
        .read_mbx => {
            const in_content = try mailbox.readMailboxInTimeout(
                port,
                station_address,
                recv_timeout_us,
                config.mbx_in,
                mbx_timeout_us,
            );

            if (in_content != .coe) {
                if (diag) |diag_ptr| {
                    diag_ptr.* = in_content;
                }
                return error.WrongProtocol;
            }
            switch (in_content.coe) {
                .abort => {
                    if (diag) |diag_ptr| {
                        diag_ptr.* = in_content;
                    }
                    return error.Aborted;
                },
                .segment => {
                    if (diag) |diag_ptr| {
                        diag_ptr.* = in_content;
                    }
                    return error.UnexpectedSegment;
                },
                .normal => {
                    if (diag) |diag_ptr| {
                        diag_ptr.* = in_content;
                    }
                    return error.UnexpectedNormal;
                },
                .emergency => {
                    if (diag) |diag_ptr| {
                        diag_ptr.* = in_content;
                    }
                    return error.Emergency;
                },
                .expedited => return,
            }
        },
    }
}

// TODO: diag mailbox content?
/// Read a packed type from an SDO.
pub fn sdoReadPack(
    port: *Port,
    station_address: u16,
    index: u16,
    subindex: u8,
    complete_access: bool,
    comptime packed_type: type,
    recv_timeout_us: u32,
    mbx_timeout_us: u32,
    cnt: u3,
    config: mailbox.Configuration,
) !packed_type {
    assert(config.isValid());

    var bytes = wire.zerosFromPack(packed_type);
    const n_bytes_read = try sdoRead(
        port,
        station_address,
        index,
        subindex,
        complete_access,
        &bytes,
        recv_timeout_us,
        mbx_timeout_us,
        cnt,
        config,
        null,
    );
    if (n_bytes_read != bytes.len) {
        std.log.err("expected pack size: {}, got {}", .{ bytes.len, n_bytes_read });
        return error.WrongPackSize;
    }
    return wire.packFromECat(packed_type, bytes);
}

// TODO: support segmented reads
/// Read the SDO from the subdevice into a buffer.
///
/// Returns number of bytes written on success.
///
/// Rather weirdly, it appears that complete access = true and subindex 0
/// will return two bytes for subindex 0, which is given type u8 in the
/// the beckhoff manuals.
/// You should probably just use complete access = true, subindex 1.
pub fn sdoRead(
    port: *Port,
    station_address: u16,
    index: u16,
    subindex: u8,
    complete_access: bool,
    out: []u8,
    recv_timeout_us: u32,
    mbx_timeout_us: u32,
    cnt: u3,
    config: mailbox.Configuration,
    diag: ?*mailbox.InContent,
) !usize {
    assert(cnt != 0);
    if (complete_access) {
        assert(subindex == 1 or subindex == 0);
    }
    assert(config.isValid());

    var fbs = std.io.fixedBufferStream(out);
    const writer = fbs.writer();

    var in_content: mailbox.InContent = undefined;
    const State = enum {
        send_read_request,
        read_mbx,
        expedited,
        normal,
        segment,
        request_segment,
        read_mbx_segment,
    };
    state: switch (State.send_read_request) {
        .send_read_request => {
            // The coding of a normal and expedited upload request is identical.
            // We issue and upload request and the server may respond with an
            // expedited, normal, or segmented response. The server will respond
            // with an expedited response if the data is less than 4 bytes,
            // a normal response if the data is more than 4 bytes and can fit into
            // a single mailbox, and a segmented response if the data is larger
            // than the mailbox.
            const request = mailbox.OutContent{
                .coe = OutContent{
                    .expedited = client.Expedited.initUploadRequest(
                        cnt,
                        index,
                        subindex,
                        complete_access,
                    ),
                },
            };
            try mailbox.writeMailboxOut(
                port,
                station_address,
                recv_timeout_us,
                config.mbx_out,
                request,
            );
            continue :state .read_mbx;
        },

        .read_mbx => {
            in_content = try mailbox.readMailboxInTimeout(
                port,
                station_address,
                recv_timeout_us,
                config.mbx_in,
                mbx_timeout_us,
            );

            if (in_content != .coe) {
                if (diag) |diag_ptr| {
                    diag_ptr.* = in_content;
                }
                return error.WrongProtocol;
            }
            switch (in_content.coe) {
                .abort => {
                    if (diag) |diag_ptr| {
                        diag_ptr.* = in_content;
                    }
                    return error.Aborted;
                },
                .expedited => continue :state .expedited,
                .segment => {
                    if (diag) |diag_ptr| {
                        diag_ptr.* = in_content;
                    }
                    return error.UnexpectedSegment;
                },
                .normal => continue :state .normal,
                .emergency => {
                    if (diag) |diag_ptr| {
                        diag_ptr.* = in_content;
                    }
                    return error.Emergency;
                },
            }
        },
        .expedited => {
            assert(in_content == .coe);
            assert(in_content.coe == .expedited);
            try writer.writeAll(in_content.coe.expedited.data.slice());
            return fbs.getWritten().len;
        },
        .normal => {
            assert(in_content == .coe);
            assert(in_content.coe == .normal);

            const data: []u8 = in_content.coe.normal.data.slice();
            try writer.writeAll(data);
            if (in_content.coe.normal.complete_size > data.len) {
                continue :state .request_segment;
            }
            return fbs.getWritten().len;
        },
        .request_segment => return error.NotImplemented,
        .segment => return error.NotImplemented,
        .read_mbx_segment => return error.NotImplemented,
    }
    unreachable;
}

/// Cnt session id for CoE
///
/// Ref: IEC 61158-6-12:2019 5.6.1
pub const Cnt = struct {
    // 0 reserved, next after 7 is 1
    cnt: u3 = 1,

    // TODO: atomics / thread safety
    pub fn nextCnt(self: *Cnt) u3 {
        const next_cnt: u3 = switch (self.cnt) {
            0 => unreachable,
            1 => 2,
            2 => 3,
            3 => 4,
            4 => 5,
            5 => 6,
            6 => 7,
            7 => 1,
        };
        assert(next_cnt != 0);
        self.cnt = next_cnt;
        return next_cnt;
    }
};

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
            false,
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
    get_od_list_response = 0x02,
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
    _,
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

/// Map of indexes in the CoE Communication Area
///
/// Ref: IEC 61158-6-12:2019 5.6.7.4
pub const CommunicationAreaMap = enum(u16) {
    device_type = 0x1000,
    error_register = 0x1001,

    manufacturer_device_name = 0x1008,
    manufacturer_hardware_version = 0x1009,
    manufacturer_software_version = 0x100A,
    identity_object = 0x1018,
    sync_manager_communication_type = 0x1c00,

    pub fn smChannel(sm: u5) u16 {
        return 0x1c10 + @as(u16, sm);
    }
    pub fn smSync(sm: u5) u16 {
        return 0x1c30 + @as(u16, sm);
    }
};

/// Device Type
///
/// Ref: IEC 61158-6-12:2019 5.6.7.4.1
pub const DeviceType = packed struct(u32) {
    device_profile: u16,
    profile_info: u16,
};

/// Error Register
///
/// Ref: IEC 61158-6-12:2019 5.6.7.4.2
pub const ErrorRegister = packed struct(u8) {
    generic: bool,
    current: bool,
    voltage: bool,
    temperature: bool,
    communication: bool,
    device_profile_specific: bool,
    reserved: bool,
    manufacturer_specific: bool,
};

/// Manufacturer Device Name
///
/// Ref: IEC 61158-6-12:2019 5.6.7.4.3
pub const ManufacturerDeviceName = []const u8;

/// Manufacturer Hardware Version
///
/// Ref: IEC 61158-6-12:2019 5.6.7.4.4
pub const ManufacturerHardwareVersion = []const u8;

/// Manufacturer Software Version
///
/// Ref: IEC 61158-6-12:2019 5.6.7.4.6
pub const ManufacturerSoftwareVersion = []const u8;

/// Identity Object
///
/// Ref: IEC 61158-6-12:2019 5.6.7.4.6
pub const IdentityObject = struct {
    /// subindex 1
    vendor_id: u32,
    /// subindex 2
    product_code: u32,
    /// subindex 3
    revision_number: u32,
    /// subindex 4
    serial_number: u32,
};

/// SM Communication Type
///
/// Ref: IEC 61158-6-12:2019 5.6.7.4.9
pub const SMComm = enum(u8) {
    unused = 0,
    mailbox_out = 1,
    mailbox_in = 2,
    output = 3,
    input = 4,
    _,
};

pub const SMComms = std.BoundedArray(SMComm, max_sm);

pub fn readSMComms(
    port: *Port,
    station_address: u16,
    recv_timeout_us: u32,
    mbx_timeout_us: u32,
    cnt: *Cnt,
    config: mailbox.Configuration,
) !SMComms {
    const n_sm = try sdoReadPack(
        port,
        station_address,
        @intFromEnum(CommunicationAreaMap.sync_manager_communication_type),
        0,
        false,
        u8,
        recv_timeout_us,
        mbx_timeout_us,
        cnt.nextCnt(),
        config,
    );

    if (n_sm > 32) return error.InvalidSMComms;

    var sm_comms = SMComms{};
    for (0..n_sm) |sm_idx| {
        sm_comms.append(try sdoReadPack(
            port,
            station_address,
            @intFromEnum(CommunicationAreaMap.sync_manager_communication_type),
            @intCast(sm_idx + 1),
            false,
            SMComm,
            recv_timeout_us,
            mbx_timeout_us,
            cnt.nextCnt(),
            config,
        )) catch unreachable; // length already checked
    }
    return sm_comms;
}

pub fn isValidPDOIndex(index: u16) bool {
    // PDOs can have indices from 0x1600 to 0x1BFF (inclusive)
    return index >= 0x1600 and index <= 0x1BFF;
}

/// Sync Manager Channel
///
/// The u16 in this array is the PDO index.
///
/// Ref: IEC 61158-6-12:2019 5.6.7.4.10.1
/// Note: the spec uses both the terms "channel" and "PDO assignment"
/// to refer to this structure. Its purpose is to assign PDOs to this
/// sync manager.
pub const SMChannel = std.BoundedArray(u16, 254);

pub fn readSMChannel(
    port: *Port,
    station_address: u16,
    recv_timeout_us: u32,
    mbx_timeout_us: u32,
    cnt: *Cnt,
    config: mailbox.Configuration,
    sm_idx: u5,
) !SMChannel {
    const index = CommunicationAreaMap.smChannel(sm_idx);

    const n_pdo = try sdoReadPack(
        port,
        station_address,
        index,
        0,
        false,
        u8,
        recv_timeout_us,
        mbx_timeout_us,
        cnt.nextCnt(),
        config,
    );

    if (n_pdo > 254) return error.InvalidSMChannel;

    var channel = SMChannel{};
    for (0..n_pdo) |i| {
        const pdo_index = try sdoReadPack(
            port,
            station_address,
            index,
            @intCast(i + 1),
            false,
            u16,
            recv_timeout_us,
            mbx_timeout_us,
            cnt.nextCnt(),
            config,
        );
        if (!isValidPDOIndex(pdo_index)) return error.InvalidSMChannelPDOIndex;
        channel.append(pdo_index) catch unreachable; // length already checked
    }
    return channel;
}

/// Sync Manager Synchronization Type
///
/// Ref: IEC 61158-6-12:2019 5.6.7.4.11
pub const SMSyncType = enum(u16) {
    not_synchronized = 0,
    /// Synchronized iwth AL event on this SM
    sm_synchron = 1,
    /// Synchronized with AL event Sync0
    dc_sync0 = 2,
    /// Synchronized with AL event Sync1
    dc_sync1 = 3,
    _,
    /// synchronized with AL event of SMxx
    pub fn syncSM(sm: u5) u16 {
        return 32 + @as(u16, sm);
    }
};

/// Sync Manager Synchronization
///
/// Ref: IEC 61158-6-12:2019 5.6.7.4.11
pub const SMSynchronization = struct {
    // subindex 0 can be 1-3
    sync_type: SMSyncType,
    cycle_time_ns: ?u32,
    shift_time_ns: ?u32,
};

pub fn readSMSync(
    port: *Port,
    station_address: u16,
    recv_timeout_us: u32,
    mbx_timeout_us: u32,
    cnt: *Cnt,
    config: mailbox.Configuration,
    sm_idx: u5,
) !SMSynchronization {
    const index = CommunicationAreaMap.smChannel(sm_idx);

    const n_params = try sdoReadPack(
        port,
        station_address,
        index,
        0,
        false,
        u8,
        recv_timeout_us,
        mbx_timeout_us,
        cnt.nextCnt(),
        config,
    );

    if (n_params > 3 or n_params == 0) return error.InvalidSMSync;

    const sync_type = try sdoReadPack(
        port,
        station_address,
        index,
        1,
        false,
        SMSyncType,
        recv_timeout_us,
        mbx_timeout_us,
        cnt.nextCnt(),
        config,
    );

    const cycle_time: ?u32 = blk: {
        if (n_params < 2) break :blk null;

        break :blk try sdoReadPack(
            port,
            station_address,
            index,
            2,
            false,
            u32,
            recv_timeout_us,
            mbx_timeout_us,
            cnt.nextCnt(),
            config,
        );
    };

    const shift_time: ?u32 = blk: {
        if (n_params < 3) break :blk null;

        break :blk try sdoReadPack(
            port,
            station_address,
            index,
            3,
            false,
            u32,
            recv_timeout_us,
            mbx_timeout_us,
            cnt.nextCnt(),
            config,
        );
    };

    return SMSynchronization{
        .sync_type = sync_type,
        .cycle_time_ns = cycle_time,
        .shift_time_ns = shift_time,
    };
}

/// The maximum number of sync managers is limited to 32.
///
/// Ref: IEC 61158-6-12:2019 5.6.7.4
pub const max_sm = 32;

/// PDO Mapping
///
/// Tx and Rx are both represented here.
///
/// Ref: IEC 61158-6-12:2019 5.6.7.4.7
pub const PDOMapping = struct {
    entries: Entries,

    pub const Entries = std.BoundedArray(Entry, 254);

    /// PDO Mapping Entry
    ///
    /// The PDO mapping index contains multiple subindices.
    ///
    /// Ref: IEC 61158-6-12:2019 5.6.7.4.7
    pub const Entry = packed struct(u32) {
        bit_length: u8,
        /// shall be zero if gap in PDO
        subindex: u8,
        /// shall be zero if gap in PDO
        index: u16,

        /// A gap is padding in the PDO. It is still included
        /// in the process image but the subdevice does nothing with it.
        /// Typically this is for byte-alignment.
        pub fn isGap(self: Entry) bool {
            return self.index == 0;
        }
    };

    pub fn bitLength(self: PDOMapping) u32 {
        var bit_length: u32 = 0;
        for (self.entries.slice()) |entry| {
            bit_length += entry.bit_length;
        }
        return bit_length;
    }
};

pub fn readPDOMapping(
    port: *Port,
    station_address: u16,
    recv_timeout_us: u32,
    mbx_timeout_us: u32,
    cnt: *Cnt,
    config: mailbox.Configuration,
    index: u16,
) !PDOMapping {
    assert(isValidPDOIndex(index));

    const n_entries = try sdoReadPack(
        port,
        station_address,
        index,
        0,
        false,
        u8,
        recv_timeout_us,
        mbx_timeout_us,
        cnt.nextCnt(),
        config,
    );

    var entries = PDOMapping.Entries{};
    if (n_entries > entries.capacity()) return error.InvalidCoEEntries;

    for (0..n_entries) |i| {
        entries.append(try sdoReadPack(
            port,
            station_address,
            index,
            // the subindex of the CoE obeject is 1 + the sm_idx. (subindex 1 contains the data for SM0)
            @intCast(i + 1),
            false,
            PDOMapping.Entry,
            recv_timeout_us,
            mbx_timeout_us,
            cnt.nextCnt(),
            config,
        )) catch unreachable;
    }

    return PDOMapping{ .entries = entries };
}

pub fn readSMPDOAssigns(
    port: *Port,
    station_address: u16,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
    mbx_timeout_us: u32,
    cnt: *Cnt,
    config: mailbox.Configuration,
) !sii.SMPDOAssigns {
    var res = sii.SMPDOAssigns{};

    const sm_catagory = try sii.readSMCatagory(
        port,
        station_address,
        recv_timeout_us,
        eeprom_timeout_us,
    );
    if (sm_catagory.len == 0) return res;
    const sync_managers = sm_catagory.slice();

    for (sync_managers, 0..) |sm_config, sm_idx| {
        switch (sm_config.syncM_type) {
            .mailbox_in, .mailbox_out, .not_used_or_unknown => {},
            _ => return error.SMAssigns,
            .process_data_inputs, .process_data_outputs => |direction| {
                try res.addSyncManager(sm_config, @intCast(sm_idx));

                const sm_pdo_assignment = try mailbox.coe.readSMChannel(port, station_address, recv_timeout_us, mbx_timeout_us, cnt, config, @intCast(sm_idx));

                for (sm_pdo_assignment.slice()) |pdo_index| {
                    const pdo_mapping = try mailbox.coe.readPDOMapping(port, station_address, recv_timeout_us, mbx_timeout_us, cnt, config, pdo_index);
                    for (pdo_mapping.entries.slice()) |entry| {
                        try res.addPDOBitsToSM(
                            entry.bit_length,
                            @intCast(sm_idx),
                            switch (direction) {
                                .process_data_inputs => .input,
                                .process_data_outputs => .output,
                                else => unreachable,
                            },
                        );
                    }
                }
            },
        }
    }
    try res.sortAndVerifyNonOverlapping();
    return res;
}

/// Basic Data Type Area
///
/// Ref: IEC 61158-6-12:2019 5.6.7.3 Table 64
pub const DataTypeArea = enum(u16) {
    /// the table does not explicitly mark this as padding but it
    /// seems beckhoff is using 0 for padding.
    PADDING = 0x0000,
    BOOLEAN = 0x0001,
    INTEGER8 = 0x0002,
    INTEGER16 = 0x0003,
    INTEGER32 = 0x0004,
    UNSIGNED8 = 0x0005,
    UNSIGNED16 = 0x0006,
    UNSIGNED32 = 0x0007,
    REAL32 = 0x0008,
    VISIBLE_STRING = 0x0009,
    OCTET_STRING = 0x000a,
    UNICODE_STRING = 0x000b,
    TIME_OF_DAY = 0x000c,
    TIME_DIFFERENCE = 0x000d,
    // reserved = 0x00e
    DOMAIN = 0x000f,
    INTEGER24 = 0x0010,
    REAL64 = 0x0011,
    INTEGER40 = 0x0012,
    INTEGER48 = 0x0013,
    INTEGER56 = 0x0014,
    INTEGER64 = 0x0015,
    UNSIGNED24 = 0x0016,
    // reserved = 0x0017
    UNSIGNED40 = 0x0018,
    UNSIGNED48 = 0x0019,
    UNSIGNED56 = 0x001a,
    UNSIGNED64 = 0x001b,
    // reserved = 0x001c,
    GUID = 0x001d,
    BYTE = 0x001e,
    // reserved = 0x001f-0x002c
    BITARR8 = 0x002d,
    BITARR16 = 0x002e,
    BITARR32 = 0x002f,
    // reserved = 0x0020
    PDO_MAPPING = 0x0021,
    // reserved = 0x0022,
    IDENTITY = 0x0023,
    // reserved = 0x0024,
    COMMAND_PAR = 0x0025,
    // reserved = 0x0026-0x0028
    SYNC_PAR = 0x0029,
    // reserved = 0x002a-0x002f
    BIT1 = 0x0030,
    BIT2 = 0x0031,
    BIT3 = 0x0032,
    BIT4 = 0x0033,
    BIT5 = 0x0034,
    BIT6 = 0x0035,
    BIT7 = 0x0036,
    BIT8 = 0x0037,
    // reserved = 0x0038-0x003f
    // rest is device profile stuff and reserved
    _,
};

test {
    std.testing.refAllDecls(@This());
}
