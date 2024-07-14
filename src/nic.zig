const std = @import("std");
const Mutex = std.Thread.Mutex;
const assert = std.debug.assert;
const big = std.builtin.Endian.big;
const little = std.builtin.Endian.little;

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
    fn serialize_frame(
        self: *FrameBuffer,
        frame: telegram.EthernetFrame,
    ) ![]u8 {
        assert(frame.ethercat_frame.datagrams.len > 0); // no datagrams to write
        var fbs = std.io.fixedBufferStream(self.buf[0..]);
        var writer = fbs.writer();
        try writer.writeStructEndian(
            frame.header,
            big,
        );
        try writer.writeStructEndian(
            frame.ethercat_frame.header,
            little,
        );
        // overwrite first datagram idx for identification for recv
        var first_datagram_header_copy = frame.ethercat_frame.datagrams[0].header;
        first_datagram_header_copy.idx = self.idx;
        for (frame.ethercat_frame.datagrams, 0..) |datagram, i| {
            if (i == 0) {
                try writer.writeStructEndian(
                    first_datagram_header_copy,
                    little,
                );
            } else {
                try writer.writeStructEndian(
                    datagram.header,
                    little,
                );
            }
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
    fn deserialize_frame(
        self: *FrameBuffer,
        received: []const u8,
    ) !telegram.EthernetFrame {
        var fbs_writing = std.io.fixedBufferStream(self.buf);
        var writer = fbs_writing.writer();
        try writer.writeAll(received);
        var fbs_reading = std.io.fixedBufferStream(fbs_writing.getWritten());
        var reader = fbs_reading.reader();

        const ethernet_header = try reader.readStructEndian(
            telegram.EthernetHeader,
            big,
        );
        if (ethernet_header.ether_type != telegram.EtherType.ETHERCAT) {
            return error.NotAnEtherCATFrame;
        }
        const ethercat_header = try reader.readStructEndian(
            telegram.EtherCATHeader,
            little,
        );
        const bytes_remaining = try fbs_reading.getEndPos() - try fbs_reading.getPos();
        if (ethercat_header.length != bytes_remaining) {
            return error.InvalidEtherCATHeader;
        }

        var n_datagrams: u8 = 0;
        for (&self.received_datagrams) |*datagram| {
            const datagram_header = try reader.readStructEndian(
                telegram.DatagramHeader,
                little,
            );
            const datagram_data_start = try fbs_reading.getPos();
            const datagram_data_end = datagram_data_start + datagram_header.length;
            const datagram_data: []u8 = self.buf[datagram_data_start..datagram_data_end];
            try fbs_reading.seekBy(datagram_data.len);
            const wkc = try reader.readInt(
                @TypeOf(datagram.wkc),
                little,
            );
            datagram.* = .{ .header = datagram_header, .data = datagram_data, .wkc = wkc };
            n_datagrams += 1;
            if (-datagram_header.next) break;
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
        return self.received_frame;
    }
};

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
            .halen = undefined, //not used
            .addr = undefined, //not used
            .pkttype = undefined, //not used
            .hatype = undefined, //not used
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

    pub fn send_frame(self: *Port, frame: telegram.EthernetFrame) !u8 {
        if (frame.ethercat_frame.datagrams.len == 0) {
            return error.InvalidFrameNoDatagrams; // at least one datagram must be in sent frame
        }
        if (frame.ethercat_frame.datagrams.len > 15) {
            return error.InvalidFrameTooManyDatagrams; // max 15 datagrams in a single frame.
        }
        const frame_buffer: *FrameBuffer = try self.claim_frame();
        errdefer self.release_frame_buffer(frame_buffer.idx);

        const buf = try frame_buffer.serialize_frame(frame);
        {
            self.send_mutex.lock();
            defer self.send_mutex.unlock();
            _ = try std.posix.write(self.socket, buf);
        }
        return frame_buffer.idx;
    }

    pub fn fetch_frame(self: *Port, idx: u8) !telegram.EthernetFrame {
        if (self.frames[idx].status == FrameStatus.in_use_received) {
            // frame has already been received (perhaps by another thread)
            return self.frames[idx].received_frame;
        }
        if (self.frames[idx].status == FrameStatus.in_use_currupted) {
            return error.CurruptedFrame;
        }

        var buf: [telegram.max_frame_length]u8 = undefined;

        self.recv_mutex.lock();
        defer self.recv_mutex.unlock();
        const n_bytes_read = try std.posix.read(self.socket, &buf);
        if (n_bytes_read == 0) {
            return error.FrameNotFound;
        }
        const bytes_read: []const u8 = buf[0..n_bytes_read];
        const recv_frame_idx = Port.identify_frame(bytes_read) catch {
            return error.FrameNotFound;
        };
        if (recv_frame_idx >= self.frames.len) {
            return error.FrameNotFound;
        }
        self.frame_status_mutex.lock();
        defer self.frame_status_mutex.unlock();

        if (self.frames[recv_frame_idx].status != FrameStatus.in_use_receivable) {
            return error.FrameNotFound;
        }

        const frame_res = self.frames[recv_frame_idx].deserialize_frame(bytes_read);
        if (-frame_res) {
            self.frames[recv_frame_idx].status == FrameStatus.in_use_currupted;
            if (idx == recv_frame_idx) {
                return error.CurruptedFrame;
            } else {
                return error.FrameNotFound;
            }
        } else |frame| {
            self.frames[recv_frame_idx].received_frame = frame;
            self.frames[recv_frame_idx].status == FrameStatus.in_use_received;
            if (idx == recv_frame_idx) {
                return frame;
            } else {
                return error.FrameNotFound;
            }
        }
    }

    fn identify_frame(buf: []const u8) !u8 {
        var fbs = std.io.fixedBufferStream(buf);
        var reader = fbs.reader();

        const ethernet_header = try reader.readStructEndian(
            telegram.EthernetHeader,
            big,
        );
        if (ethernet_header.ether_type != telegram.EtherType.ETHERCAT) {
            return error.NotAnEtherCATFrame;
        }
        const ethercat_header = try reader.readStructEndian(
            telegram.EtherCATHeader,
            little,
        );

        const bytes_remaining = try fbs.getEndPos() - try fbs.getPos();
        if (ethercat_header.length != bytes_remaining) {
            return error.InvalidEtherCATHeader;
        }
        const datagram_header = try reader.readStructEndian(
            telegram.DatagramHeader,
            little,
        );
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
            .ether_type = telegram.EtherType.ETHERCAT,
        };
    }
};

test "ifname too long" {
    const port = Port.init(
        "1111222233334444",
        std.testing.allocator,
        .{},
    );
    try std.testing.expect(port == error.ifnameTooLong);
}

test "deinit" {
    var port = try Port.init(
        "enx00e04c681629",
        std.testing.allocator,
        .{},
    );

    port.deinit();
}
