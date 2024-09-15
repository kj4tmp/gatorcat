const std = @import("std");
const Timer = std.time.Timer;
const ns_per_us = std.time.ns_per_us;
const assert = std.debug.assert;

pub const coe = @import("mailbox/coe.zig");

const commands = @import("commands.zig");
const nic = @import("nic.zig");
const esc = @import("esc.zig");
const telegram = @import("telegram.zig");
const wire = @import("wire.zig");

pub fn writeMailboxOut(
    port: *nic.Port,
    station_address: u16,
    recv_timeout_us: u32,
    content: OutContent,
) !void {
    const mbx_out = try commands.fprdPackWkc(
        port,
        esc.SyncManagerAttributes,
        .{ .station_address = station_address, .offset = @intFromEnum(esc.RegisterMap.SM0) },
        recv_timeout_us,
        1,
    );

    // TODO: Check enable bit of the SM?

    // mailbox configured correctly?
    if (mbx_out.length == 0 or mbx_out.length > max_size) {
        return error.InvalidMailboxConfiguration;
    }

    if (!mbx_out.status.mailbox_full) return error.Full;

    var buf = std.mem.zeroes([max_size]u8);

    const size = try content.serialize(&buf);

    try commands.fpwrWkc(
        port,
        .{
            .station_address = station_address,
            .offset = mbx_out.physical_start_address,
        },
        buf[0..size],
        recv_timeout_us,
        1,
    );

    std.log.info("station address: 0x{x}. wrote {} bytes to mailbox out.", .{ station_address, size });
}

pub fn readMailboxIn(
    port: *nic.Port,
    station_address: u16,
    recv_timeout_us: u32,
) !InContent {
    const mbx_in = try commands.fprdPackWkc(
        port,
        esc.SyncManagerAttributes,
        .{
            .station_address = station_address,
            .offset = @intFromEnum(esc.RegisterMap.SM1),
        },
        recv_timeout_us,
        1,
    );

    // TODO: Check enable bit of the SM?

    // mailbox configured correctly?
    if (mbx_in.length == 0 or mbx_in.length > max_size) {
        return error.InvalidMailboxConfiguration;
    }

    if (!mbx_in.status.mailbox_full) return error.Empty;

    var buf = std.mem.zeroes([max_size]u8);

    try commands.fprdWkc(
        port,
        .{
            .station_address = station_address,
            .offset = mbx_in.physical_start_address,
        },
        buf[0..mbx_in.length],
        recv_timeout_us,
        1,
    );
    const in_content = try InContent.deserialize(&buf);
    std.log.info("station address: 0x{}. got mailbox in content: {}", .{ station_address, in_content });
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
            .coe => return InContent{ .coe = try coe.InContent.deserialize(buf) },
        };
    }

    /// identifiy the content of the mailbox in buffer
    pub fn identify(buf: []const u8) !std.meta.Tag(InContent) {
        var fbs = std.io.fixedBufferStream(buf);
        const reader = fbs.reader();
        const mbx_header = try wire.packFromECatReader(Header, reader);

        return switch (mbx_header.type) {
            .CoE => return .coe,
            .ERR, .AoE, .EoE, .FoE, .SoE, .VoE => return error.NotImplemented,
            _ => return error.InvalidMbxProtocol,
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
pub const max_size = 1486;
comptime {
    assert(max_size == telegram.max_frame_length - // 1514
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
    retries: u8,
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
            const sm1_res = try commands.fprdPack(
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
    if (mbx_in.length == 0 or mbx_in.length > max_size) {
        return error.InvalidMailboxConfiguration;
    }

    if (mbx_in.status.mailbox_full) {
        var buf = std.mem.zeroes([max_size]u8); // yeet!
        for (0..retries +% 1) |_| {
            const wkc = try commands.fprd(
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
            const sm0_res = try commands.fprdPack(
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
    if (mbx_out.length == 0 or mbx_out.length > max_size) {
        return error.InvalidMailboxConfiguration;
    }
}
