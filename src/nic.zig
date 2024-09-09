const std = @import("std");
const lossyCast = std.math.lossyCast;
const Mutex = std.Thread.Mutex;
const assert = std.debug.assert;
const big = std.builtin.Endian.big;
const little = std.builtin.Endian.little;
const Timer = std.time.Timer;
const ns_per_us = std.time.ns_per_us;
const native_endian = @import("builtin").target.cpu.arch.endian();

const telegram = @import("telegram.zig");

const ETH_P_ETHERCAT = @intFromEnum(@import("telegram.zig").EtherType.ETHERCAT);
const MAC_BROADCAST: u48 = 0xffff_ffff_ffff;
const MAC_SOURCE: u48 = 0xAAAA_AAAA_AAAA;

const FrameStatus = enum {
    /// available to be claimed
    available,
    /// under construction
    in_use,
    /// sent and can be received
    in_use_receivable,
    /// received
    in_use_received,
    in_use_currupted,
};

/// deserialze bytes into datagrams
fn deserialize_frame(
    received: []const u8,
    out: []telegram.Datagram,
) !void {
    var fbs_reading = std.io.fixedBufferStream(received);
    var reader = fbs_reading.reader();

    const ethernet_header = telegram.EthernetHeader{
        .dest_mac = try reader.readInt(u48, big),
        .src_mac = try reader.readInt(u48, big),
        .ether_type = try reader.readInt(u16, big),
    };
    if (ethernet_header.ether_type != @intFromEnum(telegram.EtherType.ETHERCAT)) {
        return error.NotAnEtherCATFrame;
    }
    const header_as_int: u16 = try reader.readInt(u16, little);

    const ethercat_header: telegram.EtherCATHeader = @bitCast(header_as_int);

    const bytes_remaining = try fbs_reading.getEndPos() - try fbs_reading.getPos();
    const bytes_total = try fbs_reading.getEndPos();
    if (bytes_total < telegram.min_frame_length) {
        return error.InvalidFrameLengthTooSmall;
    }
    if (ethercat_header.length > bytes_remaining) {
        std.log.debug(
            "length field: {}, remaining: {}, end pos: {}",
            .{ ethercat_header.length, bytes_remaining, try fbs_reading.getEndPos() },
        );
        return error.InvalidEtherCATHeader;
    }

    for (out) |*out_datagram| {
        const datagram_header_as_int: u80 = try reader.readInt(u80, little);
        out_datagram.header = @bitCast(datagram_header_as_int);
        std.log.debug("datagram header: {}", .{out_datagram.header});
        if (out_datagram.header.length != out_datagram.data.len) {
            return error.CurruptedFrame;
        }
        const n_bytes_read = try reader.readAll(out_datagram.data);
        if (n_bytes_read != out_datagram.data.len) {
            return error.CurruptedFrame;
        }
        out_datagram.wkc = try reader.readInt(
            @TypeOf(out_datagram.wkc),
            little,
        );
    }
}

/// serialize this frame into the out buffer
/// for tranmission on the line.
///
/// Returns slice of bytes written, or error.
fn serialize_frame(frame: *const telegram.EthernetFrame, out: []u8) ![]u8 {
    var fbs = std.io.fixedBufferStream(out);
    var writer = fbs.writer();
    try writer.writeInt(u48, frame.header.dest_mac, big);
    try writer.writeInt(u48, frame.header.src_mac, big);
    try writer.writeInt(u16, frame.header.ether_type, big);
    const header_as_int: u16 = @bitCast(frame.ethercat_frame.header);
    try writer.writeInt(
        @TypeOf(header_as_int),
        header_as_int,
        little,
    );
    for (frame.ethercat_frame.datagrams) |datagram| {
        const datagram_header_as_int: u80 = @bitCast(datagram.header);
        try writer.writeInt(
            u80,
            datagram_header_as_int,
            little,
        );
        try writer.writeAll(datagram.data);
        try writer.writeInt(
            @TypeOf(datagram.wkc),
            datagram.wkc,
            little,
        );
    }
    try writer.writeAll(frame.padding);
    return fbs.getWritten();
}

test "serialization" {
    var data: [4]u8 = .{ 0x01, 0x02, 0x03, 0x04 };
    var datagrams: [1]telegram.Datagram = .{
        telegram.Datagram{
            .header = telegram.DatagramHeader{
                .command = telegram.Command.BRD,
                .idx = 123,
                .address = 0xABCDEF12,
                .length = 0,
                .circulating = false,
                .next = false,
                .irq = 0,
            },
            .data = &data,
            .wkc = 0,
        },
    };

    const padding = std.mem.zeroes([46]u8);
    var frame = telegram.EthernetFrame{
        .header = telegram.EthernetHeader{
            .dest_mac = 0x1122_3344_5566,
            .src_mac = 0xAABB_CCDD_EEFF,
            .ether_type = @intFromEnum(telegram.EtherType.ETHERCAT),
        },
        .ethercat_frame = telegram.EtherCATFrame{
            .header = telegram.EtherCATHeader{
                .length = 0,
            },
            .datagrams = &datagrams,
        },
        .padding = undefined,
    };
    frame.padding = padding[0..frame.getRequiredPaddingLength()];
    frame.calc();

    var out_buf: [telegram.max_frame_length]u8 = undefined;
    const serialized = try serialize_frame(&frame, &out_buf);
    const expected = [_]u8{
        // zig fmt: off
        0x11, 0x22, 0x33, 0x44, 0x55, 0x66, // src mac
        0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff, // dest mac
        0x88, 0xa4, // 0xa488 big endian
        0x10, 0b0001_0_000, // length=16, reserved=0, type=1
        0x07, // BRD
        123, // idx
        0x12, 0xEF, 0xCD, 0xAB, // address
        0x04, //length
        0x00, 0x00, 0x00,
        0x01, 0x02, 0x03, 0x04, // data
        // padding (30 bytes since 30 bytes above)
        0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00,

        // zig fmt: on
    };
    try std.testing.expectEqualSlices(u8, &expected, serialized);
}

test "serialization / deserialization" {

    var data: [4]u8 = .{ 0x01, 0x02, 0x03, 0x04 };
    var datagrams: [1]telegram.Datagram = .{
        telegram.Datagram{
            .header = telegram.DatagramHeader{
                .command = telegram.Command.BRD,
                .idx = 0,
                .address = 0xABCD,
                .length = 0,
                .circulating = false,
                .next = false,
                .irq = 0,
            },
            .data = &data,
            .wkc = 0,
        },
    };

    const padding = std.mem.zeroes([46]u8);
    var frame = telegram.EthernetFrame{
        .header = telegram.EthernetHeader{
            .dest_mac = MAC_BROADCAST,
            .src_mac = MAC_SOURCE,
            .ether_type = @intFromEnum(telegram.EtherType.ETHERCAT),
        },
        .ethercat_frame = telegram.EtherCATFrame{
            .header = telegram.EtherCATHeader{
                .length = 0,
            },
            .datagrams = &datagrams,
        },
        .padding = undefined,
    };
    frame.padding = padding[0..frame.getRequiredPaddingLength()];
    frame.calc();

    var out_buf: [telegram.max_frame_length]u8 = undefined;
    const serialized = try serialize_frame(&frame, &out_buf);
    var allocator = std.testing.allocator;
    const serialize_copy = try allocator.dupe(u8, serialized);
    defer allocator.free(serialize_copy);

    var data2: [4]u8 = undefined;
    var datagrams2 = datagrams;
    datagrams2[0].data = &data2;

    try deserialize_frame(serialize_copy, &datagrams2);

    try std.testing.expectEqualDeep(frame.ethercat_frame.datagrams, &datagrams2);
}

pub fn isECatPackable(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .Struct => |_struct| blk: {
            // must be a packed struct
            break :blk (_struct.layout == .@"packed"); 
        },
        .Int, .Float => true,
        .Union => |_union| blk: {
            // must be a packed union
            break :blk (_union.layout == .@"packed"); 
        },
        else => false,
    };
}

pub fn eCatFromPackToWriter(pack: anytype, writer: anytype) !void {
    comptime assert(isECatPackable(@TypeOf(pack)));
    var bytes = eCatFromPack(pack);
    try writer.writeAll(&bytes);
} 

/// convert a packed struct to bytes that can be sent via ethercat
/// 
/// the packed struct must have bitwidth that is a multiple of 8
pub fn eCatFromPack(pack: anytype) [@divExact(@bitSizeOf(@TypeOf(pack)), 8)]u8 {
    comptime assert(isECatPackable(@TypeOf(pack)));
    var bytes: [@divExact(@bitSizeOf(@TypeOf(pack)), 8)]u8 = undefined;
    switch (native_endian) {
        .little => {
            bytes = @bitCast(pack);
        },
        .big => {
            bytes = @bitCast(pack);
            std.mem.reverse(u8, &bytes);
        },
    }
    return bytes;
}

pub fn zerosFromPack(comptime T: type) [@divExact(@bitSizeOf(T), 8)]u8 {
    comptime assert(isECatPackable(T));
    return std.mem.zeroes([@divExact(@bitSizeOf(T), 8)]u8);
}

test "eCatFromPack" {
    const Command = packed struct(u8) {
        flag: bool = true,
        reserved: u7 = 0,
    };
    try std.testing.expectEqual(
        [_]u8{1},
        eCatFromPack(Command{}),
    );

    const Command2 = packed struct(u16) {
        flag: bool = true,
        reserved: u7 = 0,
        num: u8 = 7,
    };
    try std.testing.expectEqual(
        [_]u8{1, 7},
        eCatFromPack(Command2{}),
    );

    const Command3 = packed struct(u24) {
        flag: bool = true,
        reserved: u7 = 0,
        num: u16 = 0x1122,
    };
    try std.testing.expectEqual(
        [_]u8{1, 0x22, 0x11},
        eCatFromPack(Command3{}),
    );

    const Command4 = packed struct(u32) {
        flag: bool = true,
        reserved: u7 = 0,
        num: u16 = 0x1122,
        num2: u5 = 0x03,
        num3: u3 = 0,
    };
    try std.testing.expectEqual(
        [_]u8{1, 0x22, 0x11, 0x03},
        eCatFromPack(Command4{}),
    );
    const Command5 = packed struct(u40) {
        flag: bool = true,
        reserved: u7 = 0,
        num: u16 = 0x1122,
        num2: u5 = 0x03,
        num3: u3 = 0,
        num4: u8 = 0xAB,
    };
    try std.testing.expectEqual(
        [_]u8{1, 0x22, 0x11, 0x03, 0xAB},
        eCatFromPack(Command5{}),
    );
}

/// Read a packed struct, int, or float from a reader containing
/// EtherCAT (little endian) data into host endian representation.
pub fn packFromECatReader(comptime T: type, reader: anytype) !T {
    comptime assert(isECatPackable(T));
    var bytes: [@divExact(@bitSizeOf(T), 8)]u8 = undefined;
    try reader.readNoEof(&bytes);
    return packFromECat(T, bytes);
}

test packFromECatReader {
    const bytes = [_]u8{0,1,2};
    var fbs = std.io.fixedBufferStream(&bytes);
    const reader = fbs.reader();
    const Pack = packed struct (u24) {
        a: u8,
        b: u8,
        c: u8,
    };
    const expected_pack = Pack{.a = 0, .b = 1, .c = 2};
    const actual_pack = packFromECatReader(Pack, reader);

    try std.testing.expectEqualDeep(expected_pack, actual_pack);
}


pub fn packFromECat(comptime T: type, ecat_bytes: [@divExact(@bitSizeOf(T), 8)]u8) T {
    comptime assert(isECatPackable(T));
    switch (native_endian) {
        .little => {
            return @bitCast(ecat_bytes);
        },
        .big => {
            var bytes_copy = ecat_bytes;
            std.mem.reverse(u8, &bytes_copy);
            return @bitCast(bytes_copy);
        },
    }
    unreachable;
}

test "packFromECat" {
    const Command = packed struct(u8) {
        flag: bool = true,
        reserved: u7 = 0,
    };
    try std.testing.expectEqual(
        Command{},
        packFromECat(Command, [_]u8{1}),
    );

    const Command2 = packed struct(u16) {
        flag: bool = true,
        reserved: u7 = 0,
        num: u8 = 7,
    };
    try std.testing.expectEqual(
        Command2{},
        packFromECat(Command2, [_]u8{1, 7}),
    );

    const Command3 = packed struct(u24) {
        flag: bool = true,
        reserved: u7 = 0,
        num: u16 = 0x1122,
    };
    try std.testing.expectEqual(
        Command3{},
        packFromECat(Command3, [_]u8{1, 0x22, 0x11}),
    );

    const Command4 = packed struct(u32) {
        flag: bool = true,
        reserved: u7 = 0,
        num: u16 = 0x1122,
        num2: u5 = 0x03,
        num3: u3 = 0,
    };
    try std.testing.expectEqual(
        Command4{},
        packFromECat(Command4, [_]u8{1, 0x22, 0x11, 0x03}),
        
    );
    const Command5 = packed struct(u40) {
        flag: bool = true,
        reserved: u7 = 0,
        num: u16 = 0x1122,
        num2: u5 = 0x03,
        num3: u3 = 0,
        num4: u8 = 0xAB,
    };
    try std.testing.expectEqual(
        Command5{},
        packFromECat(Command5, [_]u8{1, 0x22, 0x11, 0x03, 0xAB}),
    );
}



pub const Port = struct {
    recv_datagrams_status_mutex: Mutex = .{},
    send_mutex: Mutex = .{},
    recv_mutex: Mutex = .{},
    socket: std.posix.socket_t,
    recv_datagrams: [128][]telegram.Datagram = undefined,
    recv_datagrams_status: [128]FrameStatus = [_]FrameStatus{FrameStatus.available}**128,

    pub fn init(
        ifname: []const u8,
    ) !Port {
        assert(ifname.len <= std.posix.IFNAMESIZE - 1); // ifname too long
        const socket: std.posix.socket_t = try std.posix.socket(
            std.posix.AF.PACKET,
            std.posix.SOCK.RAW,
            std.mem.nativeToBig(u32, ETH_P_ETHERCAT),
        );
        var timeout_rcv = std.posix.timeval{
            .tv_sec = 0,
            .tv_usec = 1,
        };
        try std.posix.setsockopt(
            socket,
            std.posix.SOL.SOCKET,
            std.posix.SO.RCVTIMEO,
            std.mem.asBytes(&timeout_rcv),
        );

        var timeout_snd = std.posix.timeval{
            .tv_sec = 0,
            .tv_usec = 1,
        };
        try std.posix.setsockopt(
            socket,
            std.posix.SOL.SOCKET,
            std.posix.SO.SNDTIMEO,
            std.mem.asBytes(&timeout_snd),
        );
        const dontroute_enable: c_int = 1;
        try std.posix.setsockopt(
            socket,
            std.posix.SOL.SOCKET,
            std.posix.SO.DONTROUTE,
            std.mem.asBytes(&dontroute_enable),
        );
        var ifr: std.posix.ifreq = std.mem.zeroInit(std.posix.ifreq, .{});
        @memcpy(ifr.ifrn.name[0..ifname.len], ifname);
        ifr.ifrn.name[ifname.len] = 0;
        try std.posix.ioctl_SIOCGIFINDEX(socket, &ifr);
        const ifindex: i32 = ifr.ifru.ivalue;

        const IFF_PROMISC = 256;
        const IFF_BROADCAST = 2;
        const SIOCGIFFLAGS = 0x8913;
        const SIOCSIFFLAGS = 0x8914;

        var rval = std.posix.errno(std.os.linux.ioctl(socket, SIOCGIFFLAGS, @intFromPtr(&ifr)));
        switch (rval) {
            .SUCCESS => {},
            else => {
                return error.nicError;
            },
        }
        ifr.ifru.flags = ifr.ifru.flags | IFF_BROADCAST | IFF_PROMISC;
        rval = std.posix.errno(std.os.linux.ioctl(socket, SIOCSIFFLAGS, @intFromPtr(&ifr)));
        switch (rval) {
            .SUCCESS => {},
            else => {
                return error.nicError;
            },
        }
        const sockaddr_ll = std.posix.sockaddr.ll{
            .family = std.posix.AF.PACKET,
            .ifindex = ifindex,
            .protocol = std.mem.nativeToBig(u16, @as(u16, ETH_P_ETHERCAT)),
            .halen = 0, //not used
            .addr = .{ 0, 0, 0, 0, 0, 0, 0, 0 }, //not used
            .pkttype = 0, //not used
            .hatype = 0, //not used
        };
        try std.posix.bind(socket, @ptrCast(&sockaddr_ll), @sizeOf(@TypeOf(sockaddr_ll)));
        return Port{
            .socket = socket,
        };
    }
    pub fn deinit(self: *Port) void {
        _ = self;
        // TODO: de init socket
    }

    /// claim transaction
    /// 
    /// claim a transaction idx with the ethercat bus.
    pub fn claim_transaction(self: *Port) error{NoTransactionAvailable}!u8 {
        self.recv_datagrams_status_mutex.lock();
        defer self.recv_datagrams_status_mutex.unlock();

        for (&self.recv_datagrams_status, 0..) |*status, idx| {
            if (status.* == FrameStatus.available) {
                status.* = FrameStatus.in_use;
                return @intCast(idx);
            }
        } else {
            return error.NoTransactionAvailable;
        }
    }

    /// Send a transaction with the ethercat bus.
    /// 
    /// Parameter send_datagram is the datagram to be sent
    /// and is used to deserialize the data on response.
    pub fn send_transaction(self: *Port, idx: u8, send_datagrams: []telegram.Datagram) !void {
        assert(send_datagrams.len != 0); // no datagrams
        assert(send_datagrams.len <= 15); // too many datagrams
        assert(self.recv_datagrams_status[idx] == FrameStatus.in_use); // should claim transaction first

        // store pointer to where to deserialize frames later
        self.recv_datagrams[idx] = send_datagrams;

        // assign identity of frame as first datagram idx
        send_datagrams[0].header.idx = idx;

        const padding = std.mem.zeroes([46]u8);
        var frame = telegram.EthernetFrame{
            .header = Port.get_ethernet_header(),
            .ethercat_frame = telegram.EtherCATFrame{
                .header = telegram.EtherCATHeader{
                    .length = 0,
                },
                .datagrams = send_datagrams,
            },
            .padding = undefined,
        };
        frame.padding = padding[0..frame.getRequiredPaddingLength()];
        std.log.debug("padding len: {}", .{frame.padding.len});
        frame.calc();

        var out_buf: [telegram.max_frame_length]u8 = undefined;
        const out = serialize_frame(&frame, &out_buf) catch |err| switch (err) {
            error.NoSpaceLeft => return error.FrameSerializationFailure,
        };
        std.log.debug("send: {x}, len: {}", .{ out, out.len });
        {
            self.send_mutex.lock();
            defer self.send_mutex.unlock();
            _ = std.posix.write(self.socket, out) catch return error.SocketError;
        }
        {
            self.recv_datagrams_status_mutex.lock();
            defer self.recv_datagrams_status_mutex.unlock();
            self.recv_datagrams_status[idx] = FrameStatus.in_use_receivable;
        }
    }

    /// fetch a frame by receiving bytes
    ///
    /// returns immediatly
    ///
    /// call using idx from claim transaction and used by begin transaction
    /// 
    /// Returns false if return frame was not found (call again to try to recieve it).
    /// 
    /// Returns true when frame has been deserailized successfully.
    pub fn continue_transaction(self: *Port, idx: u8) !bool {
        switch (self.recv_datagrams_status[idx]) {
            .available => unreachable,
            .in_use => unreachable,
            .in_use_receivable => {},
            .in_use_received => return true,
            .in_use_currupted => return error.CurruptedFrame,
        }
        self.recv_frame() catch |err| switch (err) {
            error.FrameNotFound => {},
            error.SocketError => {return error.SocketError;},
            error.InvalidFrame => {},
        };
        switch (self.recv_datagrams_status[idx]) {
            .available => unreachable,
            .in_use => unreachable,
            .in_use_receivable => return false,
            .in_use_received => return true,
            .in_use_currupted => return error.CurruptedFrame,
        }

    }

    fn recv_frame(self: *Port) !void {
        std.log.debug("attempting to recv...", .{});
        var buf: [telegram.max_frame_length]u8 = undefined;
        var n_bytes_read: usize = 0;
        {
            self.recv_mutex.lock();
            defer self.recv_mutex.unlock();
            n_bytes_read = std.posix.read(self.socket, &buf) catch |err| switch (err) {
                error.WouldBlock => return error.FrameNotFound,
                else => {
                    std.log.err("Socket error: {}", .{err});
                    return error.SocketError;},
            };
        }
        if (n_bytes_read == 0) {
            std.log.debug("no bytes to read", .{});
            return;
        }
        const bytes_read: []const u8 = buf[0..n_bytes_read];
        std.log.debug("recv: {x}, len: {}", .{ bytes_read, bytes_read.len });
        const recv_frame_idx = Port.identify_frame(bytes_read) catch return error.InvalidFrame;
        std.log.debug("identified frame as idx: {}", .{recv_frame_idx});

        switch (self.recv_datagrams_status[recv_frame_idx]) {
            .in_use_receivable => {
                self.recv_datagrams_status_mutex.lock();
                defer self.recv_datagrams_status_mutex.unlock();
                const frame_res = deserialize_frame(bytes_read, self.recv_datagrams[recv_frame_idx]);
                if (frame_res) {
                    self.recv_datagrams_status[recv_frame_idx] = FrameStatus.in_use_received;
                } else |err| switch (err) {
                    else => {
                        self.recv_datagrams_status[recv_frame_idx] = FrameStatus.in_use_currupted;
                        return;
                    },
                }
            },
            else => {},
        }
    }

    fn identify_frame(buf: []const u8) !u8 {
        var fbs = std.io.fixedBufferStream(buf);
        var reader = fbs.reader();
        var ethernet_header: telegram.EthernetHeader = undefined;
        ethernet_header.dest_mac = try reader.readInt(u48, big);
        ethernet_header.src_mac = try reader.readInt(u48, big);
        ethernet_header.ether_type = try reader.readInt(u16, big);
        if (ethernet_header.ether_type != @intFromEnum(telegram.EtherType.ETHERCAT)) {
            return error.NotAnEtherCATFrame;
        }
        const header_as_int: u16 = try reader.readInt(u16, little);
        const ethercat_header: telegram.EtherCATHeader = @bitCast(header_as_int);

        const bytes_remaining = try fbs.getEndPos() - try fbs.getPos();
        const bytes_total = try fbs.getEndPos();
        if (bytes_total < telegram.min_frame_length) {
            return error.InvalidFrameLengthTooSmall;
        }
        if (ethercat_header.length > bytes_remaining) {
            std.log.debug(
                "length field: {}, remaining: {}, end pos: {}",
                .{ ethercat_header.length, bytes_remaining, try fbs.getEndPos() },
            );
            return error.InvalidEtherCATHeader;
        }
        const datagram_header_as_int: u80 = try reader.readInt(u80, little);
        const datagram_header: telegram.DatagramHeader = @bitCast(datagram_header_as_int);
        return datagram_header.idx;
    }

    /// Release transaction idx.
    ///
    /// Releases a transaction so it can be used by others.
    ///
    /// Caller is inteded to use the idx returned by a previous
    /// call to send_frame.
    pub fn release_transaction(self: *Port, idx: u8) void {
        {
            self.recv_datagrams_status_mutex.lock();
            defer self.recv_datagrams_status_mutex.unlock();
            self.recv_datagrams_status[idx] = FrameStatus.available;
        }
    }


    
    pub fn get_ethernet_header() telegram.EthernetHeader {
        return telegram.EthernetHeader{
            .dest_mac = MAC_BROADCAST,
            .src_mac = MAC_SOURCE,
            .ether_type = @intFromEnum(telegram.EtherType.ETHERCAT),
        };
    }

    pub fn send_recv_datagrams(self: *Port, send_datagrams: []telegram.Datagram, timeout_us: u32,) !void {
        assert(send_datagrams.len != 0); // no datagrams
        assert(send_datagrams.len <= 15); // too many datagrams

        var timer = Timer.start() catch |err| switch (err) {
            error.TimerUnsupported => @panic("timer unsupported"),
        };
        var idx: u8 = undefined;
        while (timer.read() < timeout_us * ns_per_us) {
            idx = self.claim_transaction() catch |err| switch (err) {
                error.NoTransactionAvailable => continue
            };
            break;
        } else {
            return error.NoTransactionAvailableTimeout;
        }
        defer self.release_transaction(idx);

        try self.send_transaction(idx, send_datagrams);
        
        while (timer.read() < timeout_us * 1000) {
            if (try self.continue_transaction(idx)){
                return;
            }
        } else {
            return error.RecvTimeout;
        }
    }
};
