const std = @import("std");
const lossyCast = std.math.lossyCast;
const Mutex = std.Thread.Mutex;
const assert = std.debug.assert;
const big = std.builtin.Endian.big;
const little = std.builtin.Endian.little;
const Timer = std.time.Timer;
const ns_per_us = std.time.ns_per_us;

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

const FrameBuffer = struct {
    status: FrameStatus = FrameStatus.available,
    buf: [telegram.max_frame_length]u8,
    received_datagrams: [15]telegram.Datagram,
    received_frame: telegram.EthernetFrame,
    idx: u8,

    fn init(idx: u8) FrameBuffer {
        return FrameBuffer{
            .buf = undefined,
            .received_datagrams = undefined,
            .received_frame = undefined,
            .idx = idx,
        };
    }
    fn deserialize_frame(
        self: *FrameBuffer,
        received: []const u8,
    ) !*telegram.EthernetFrame {
        var fbs_writing = std.io.fixedBufferStream(&self.buf);
        var writer = fbs_writing.writer();
        try writer.writeAll(received);
        var fbs_reading = std.io.fixedBufferStream(fbs_writing.getWritten());
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

        var n_datagrams: u8 = 0;
        for (&self.received_datagrams) |*datagram| {
            const datagram_header_as_int: u80 = try reader.readInt(u80, little);
            const datagram_header: telegram.DatagramHeader = @bitCast(datagram_header_as_int);
            std.log.debug("datagram header: {}", .{datagram_header});
            const datagram_data_start = try fbs_reading.getPos();
            const datagram_data_end = datagram_data_start + datagram_header.length;
            const datagram_data: []u8 = self.buf[datagram_data_start..datagram_data_end];
            try fbs_reading.seekBy(lossyCast(i64, datagram_data.len));
            const wkc = try reader.readInt(
                @TypeOf(datagram.wkc),
                little,
            );
            datagram.* = .{ .header = datagram_header, .data = datagram_data, .wkc = wkc };
            n_datagrams += 1;
            if (!datagram_header.next) break;
        }
        const datagrams = self.received_datagrams[0..n_datagrams];

        const padding_start = try fbs_reading.getPos();
        const padding_end = try fbs_reading.getEndPos();
        const padding: []u8 = self.buf[padding_start..padding_end];

        const ethercat_frame: telegram.EtherCATFrame = .{
            .header = ethercat_header,
            .datagrams = datagrams,
        };

        const received_frame: telegram.EthernetFrame = .{
            .header = ethernet_header,
            .ethercat_frame = ethercat_frame,
            .padding = padding,
        };

        self.received_frame = received_frame;
        return &self.received_frame;
    }
    /// serialize this frame into the out buffer
    /// for tranmission on the line.
    ///
    /// Returns slice of bytes written, or error.
    fn serialize_frame(self: *FrameBuffer, frame: *const telegram.EthernetFrame) ![]u8 {
        var fbs = std.io.fixedBufferStream(&self.buf);
        var writer = fbs.writer();
        // try writer.writeStructEndian(
        //     self.header,
        //     big,
        // );
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
};

test "serialization" {
    var frame_buffer = FrameBuffer.init(0);

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

    const serialized = try frame_buffer.serialize_frame(&frame);
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
    var frame_buffer = FrameBuffer.init(0);

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

    const serialized = try frame_buffer.serialize_frame(&frame);
    var allocator = std.testing.allocator;
    const serialize_copy = try allocator.dupe(u8, serialized);
    defer allocator.free(serialize_copy);

    const deserialized = try frame_buffer.deserialize_frame(serialize_copy);

    try std.testing.expectEqualDeep(frame, deserialized.*);
}

pub const PortOptions = struct {
    /// max frame idx = max frames in flight - 1
    /// Make this smaller if you want to
    /// allocate less memory.
    ///
    /// u8 since that is max idx in ethercat frame.
    max_frame_idx: u8 = 127,
};

pub const Port = struct {
    frame_status_mutex: Mutex = .{},
    send_mutex: Mutex = .{},
    recv_mutex: Mutex = .{},
    socket: std.posix.socket_t,
    frames: []FrameBuffer,
    allocator: std.mem.Allocator,

    pub fn init(
        ifname: []const u8,
        allocator: std.mem.Allocator,
        args: PortOptions,
    ) !Port {
        const frames = try allocator.alloc(FrameBuffer, @as(usize, args.max_frame_idx) + 1);
        errdefer allocator.free(frames);

        var idx: u8 = 0;
        for (frames) |*frame| {
            frame.* = FrameBuffer.init(idx);
            idx +|= 1;
        }

        if (ifname.len > std.posix.IFNAMESIZE - 1) {
            return error.ifnameTooLong;
        }
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
            .frames = frames,
            .allocator = allocator,
        };
    }
    pub fn deinit(self: *Port) void {
        self.allocator.free(self.frames);
    }

    pub fn send_datagrams(self: *Port, datagrams: []telegram.Datagram) !u8 {
        assert(datagrams.len != 0); // no datagrams
        assert(datagrams.len <= 15); // too many datagrams

        const frame_buffer: *FrameBuffer = try self.claim_frame();
        errdefer self.release_frame_buffer(frame_buffer.idx);
        const padding = std.mem.zeroes([46]u8);
        var frame = telegram.EthernetFrame{
            .header = Port.get_ethernet_header(),
            .ethercat_frame = telegram.EtherCATFrame{
                .header = telegram.EtherCATHeader{
                    .length = 0,
                },
                .datagrams = datagrams,
            },
            .padding = undefined,
        };
        frame.padding = padding[0..frame.getRequiredPaddingLength()];
        std.log.debug("padding len: {}", .{frame.padding.len});
        frame.calc();

        const out = try frame_buffer.serialize_frame(&frame);
        std.log.debug("send: {x}, len: {}", .{ out, out.len });
        {
            self.send_mutex.lock();
            defer self.send_mutex.unlock();
            _ = try std.posix.write(self.socket, out);
        }
        {
            self.frame_status_mutex.lock();
            defer self.frame_status_mutex.unlock();
            frame_buffer.status = FrameStatus.in_use_receivable;
        }
        return frame_buffer.idx;
    }

    pub const FetchFrameError = error{
        CurruptedFrame,
        FrameNotFound,
    };

    /// fetch a frame by receiving bytes
    ///
    /// returns immediatly
    ///
    /// call using idx returned from send_datagrams
    pub fn fetch_datagrams(self: *Port, idx: u8) ![]telegram.Datagram {
        switch (self.frames[idx].status) {
            .available => unreachable,
            .in_use => unreachable,
            .in_use_receivable => {},
            .in_use_received => return self.frames[idx].received_frame.ethercat_frame.datagrams,
            .in_use_currupted => return error.CurruptedFrame,
        }
        try self.recv_frame();
        switch (self.frames[idx].status) {
            .available => unreachable,
            .in_use => unreachable,
            .in_use_receivable => return error.FrameNotFound,
            .in_use_received => return self.frames[idx].received_frame.ethercat_frame.datagrams,
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
                else => return err,
            };
        }
        if (n_bytes_read == 0) {
            std.log.debug("no bytes to read", .{});
            return;
        }
        const bytes_read: []const u8 = buf[0..n_bytes_read];
        std.log.debug("recv: {x}, len: {}", .{ bytes_read, bytes_read.len });
        const recv_frame_idx = try Port.identify_frame(bytes_read);
        std.log.debug("identified frame as idx: {}", .{recv_frame_idx});
        if (recv_frame_idx >= self.frames.len) {
            return;
        }

        switch (self.frames[recv_frame_idx].status) {
            .in_use_receivable => {
                self.frame_status_mutex.lock();
                defer self.frame_status_mutex.unlock();
                const frame_res = self.frames[recv_frame_idx].deserialize_frame(bytes_read);
                if (frame_res) {
                    self.frames[recv_frame_idx].status = FrameStatus.in_use_received;
                } else |err| switch (err) {
                    else => {
                        self.frames[recv_frame_idx].status = FrameStatus.in_use_currupted;
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

    /// Release Frame Buffer
    ///
    /// Releases a frame buffer so it can be claimed by others.
    ///
    /// Caller is inteded to use the idx returned by a previous
    /// call to send_frame.
    pub fn release_frame_buffer(self: *Port, idx: u8) void {
        {
            self.frame_status_mutex.lock();
            defer self.frame_status_mutex.unlock();
            self.frames[idx].status = FrameStatus.available;
        }
    }

    /// Claim a frame buffer.
    ///
    /// Only called by send_frame.
    fn claim_frame(self: *Port) error{NoFrameBufferAvailable}!*FrameBuffer {
        self.frame_status_mutex.lock();
        defer self.frame_status_mutex.unlock();

        for (self.frames) |*frame| {
            if (frame.status == FrameStatus.available) {
                frame.status = FrameStatus.in_use;
                return frame;
            }
        } else {
            return error.NoFrameBufferAvailable;
        }
    }
    pub fn get_ethernet_header() telegram.EthernetHeader {
        return telegram.EthernetHeader{
            .dest_mac = MAC_BROADCAST,
            .src_mac = MAC_SOURCE,
            .ether_type = @intFromEnum(telegram.EtherType.ETHERCAT),
        };
    }

    const SendRecvResult = struct {
        recv_datagrams: []telegram.datagram,
        idx: u8
    };

    /// caller is responsible for releasing frame buffer using 
    /// idx returned
    pub fn send_recv_datagrams(self: *Port, datagrams: []telegram.Datagram, timeout_us: u32) !SendRecvResult {
        var timer = try Timer.start();
        var idx: u8 = undefined;
        while (timer.read() < timeout_us * ns_per_us) {
            idx = self.send_datagrams(&datagrams) catch |err| switch (err) {
                error.NoFrameBufferAvailable => continue,
            };
            break;
        } else {
            return error.Timeout;
        }
        errdefer self.release_frame_buffer(idx);
        var recv_datagrams: []telegram.Datagram = undefined;
        while (timer.read() < timeout_us * 1000) {
            recv_datagrams = self.fetch_datagrams(idx) catch |err| switch (err) {
                error.FrameNotFound => {
                    std.log.err("failed to find frame", .{});
                    continue;
                },
                else => return err,
            };
        }
        return SendRecvResult{
            .recv_datagrams = recv_datagrams,
            .idx = idx,
        };
    }
};
