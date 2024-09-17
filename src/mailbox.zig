const std = @import("std");
const assert = std.debug.assert;

const commands = @import("commands.zig");
const nic = @import("nic.zig");
const esc = @import("esc.zig");
const telegram = @import("telegram.zig");
const wire = @import("wire.zig");

pub const coe = @import("mailbox/coe.zig");

pub fn writeMailboxOut(
    port: *nic.Port,
    station_address: u16,
    recv_timeout_us: u32,
    mbx_out_start_addr: u16,
    mbx_out_length: u16,
    content: OutContent,
) !void {
    assert(mbx_out_length <= max_size);
    assert(mbx_out_length > 0);

    const act_mbx_out = try commands.fprdPackWkc(
        port,
        esc.SyncManagerAttributes,
        .{ .station_address = station_address, .offset = @intFromEnum(esc.RegisterMap.SM0) },
        recv_timeout_us,
        1,
    );

    // Mailbox configured correctly?
    // Can check this for free since we already have the full SM attr.
    if (act_mbx_out.length != mbx_out_length or
        act_mbx_out.physical_start_address != mbx_out_start_addr or
        act_mbx_out.control.buffer_type != .mailbox or
        act_mbx_out.control.direction != .output or
        act_mbx_out.control.DLS_user_event_enable != true or
        act_mbx_out.activate.channel_enable != true)
    {
        // This may occur if:
        // 1. the subdevice loses power etc.
        // 2. we screwed up the configuration
        return error.InvalidMbxConfiguration;
    }

    // Mailbox out full?
    if (act_mbx_out.status.mailbox_full) return error.Full;

    var buf = std.mem.zeroes([max_size]u8);
    const size = content.serialize(&buf) catch |err| switch (err) {
        error.NoSpaceLeft => return error.InvalidParameterContentTooLarge,
    };
    assert(size > 0);

    if (size > act_mbx_out.length) return error.ContentTooLargeForMailbox;

    // The mailbox
    try commands.fpwrWkc(
        port,
        .{
            .station_address = station_address,
            .offset = act_mbx_out.physical_start_address,
        },
        // The datagram size must exactly match the mailbox size,
        // otherwise the subdevice seems to do nothing.
        buf[0..act_mbx_out.length],
        recv_timeout_us,
        1,
    );

    std.log.info("station address: 0x{x}. wrote {} bytes to mailbox out.", .{ station_address, size });
}

pub fn readMailboxIn(
    port: *nic.Port,
    station_address: u16,
    recv_timeout_us: u32,
    mbx_in_start_addr: u16,
    mbx_in_length: u16,
) !InContent {
    assert(mbx_in_length <= max_size);
    assert(mbx_in_length > 0);

    const act_mbx_in = try commands.fprdPackWkc(
        port,
        esc.SyncManagerAttributes,
        .{
            .station_address = station_address,
            .offset = @intFromEnum(esc.RegisterMap.SM1),
        },
        recv_timeout_us,
        1,
    );

    // Mailbox configured correctly?
    // Can check this for free since we already have the full SM attr.
    if (act_mbx_in.length != mbx_in_length or
        act_mbx_in.physical_start_address != mbx_in_start_addr or
        act_mbx_in.control.buffer_type != .mailbox or
        act_mbx_in.control.direction != .input or
        act_mbx_in.control.DLS_user_event_enable != true or
        act_mbx_in.activate.channel_enable != true)
    {
        // This may occur if:
        // 1. the subdevice loses power etc.
        // 2. we screwed up the configuration
        return error.InvalidMbxConfiguration;
    }

    // Mialbox empty?
    if (!act_mbx_in.status.mailbox_full) return error.Empty;

    var buf = std.mem.zeroes([max_size]u8);
    try commands.fprdWkc(
        port,
        .{
            .station_address = station_address,
            .offset = act_mbx_in.physical_start_address,
        },
        // subdevice will do nothing if this size is too big.
        buf[0..act_mbx_in.length],
        recv_timeout_us,
        1,
    );
    const in_content = try InContent.deserialize(&buf);
    std.log.info("station address: 0x{x}. got mailbox in content: {}", .{ station_address, in_content });
    return in_content;
}

/// All possible contents of MailboxOut (communication from maindevice to subdevice)
pub const OutContent = union(enum) {
    coe: coe.OutContent,

    // TODO: implement other protocols

    pub fn serialize(self: OutContent, out: []u8) !usize {
        return switch (self) {
            .coe => self.coe.serialize(out),
        };
    }
};

/// All possible contents of MailboxIn (communication from subdevice to maindevice)
pub const InContent = union(enum) {
    coe: coe.InContent,

    // TODO: implement other protocols

    pub fn deserialize(buf: []const u8) !InContent {
        return switch (try identify(buf)) {
            .coe => InContent{ .coe = coe.InContent.deserialize(buf) catch return error.InvalidMbxContent },
        };
    }

    /// identifiy the content of the mailbox in buffer
    pub fn identify(buf: []const u8) !std.meta.Tag(InContent) {
        var fbs = std.io.fixedBufferStream(buf);
        const reader = fbs.reader();
        const mbx_header = wire.packFromECatReader(Header, reader) catch return error.InvalidMbxContent;

        return switch (mbx_header.type) {
            .CoE => return .coe,
            .ERR, .AoE, .EoE, .FoE, .SoE, .VoE => return error.NotImplemented,
            _ => return error.InvalidMbxContent,
        };
    }
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
pub const Header = packed struct(u48) {
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
    mbx_header: Header,
    /// mailbox service data
    data: []u8,
};

/// The maximum mailbox size is limited by the maximum data that can be
/// read by a single datagram.
/// This applies to both mailbox out and mailbox in.
pub const max_size = 1486;
// Derivation of max_size:
comptime {
    assert(max_size == telegram.max_frame_length - // 1514
        @divExact(@bitSizeOf(telegram.EthernetHeader), 8) - // u112
        @divExact(@bitSizeOf(telegram.EtherCATHeader), 8) - // u16
        @divExact(@bitSizeOf(telegram.DatagramHeader), 8) - // u80
        @divExact(@bitSizeOf(u16), 8)); // wkc
}

/// The minimum mailbox size is the size required to hold
/// the max of:
/// 1. smallest coe segment request.
/// 2. smallest coe normal request.
/// 3. smallest coe expedited request.
pub const min_size = 16;

// TODO: derive min_size
