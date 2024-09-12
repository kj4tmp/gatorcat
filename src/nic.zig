const std = @import("std");
const lossyCast = std.math.lossyCast;
const Mutex = std.Thread.Mutex;
const assert = std.debug.assert;

const Timer = std.time.Timer;
const ns_per_us = std.time.ns_per_us;

const telegram = @import("telegram.zig");

const ETH_P_ETHERCAT = @intFromEnum(telegram.EtherType.ETHERCAT);
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

pub const Port = struct {
    recv_datagrams_status_mutex: Mutex = .{},
    send_mutex: Mutex = .{},
    recv_mutex: Mutex = .{},
    socket: std.posix.socket_t,
    recv_datagrams: [128][]telegram.Datagram = undefined,
    recv_datagrams_status: [128]FrameStatus = [_]FrameStatus{FrameStatus.available} ** 128,

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
        assert(send_datagrams.len > 0); // no datagrams
        assert(send_datagrams.len <= 15); // too many datagrams
        assert(self.recv_datagrams_status[idx] == FrameStatus.in_use); // should claim transaction first

        // store pointer to where to deserialize frames later
        self.recv_datagrams[idx] = send_datagrams;

        // assign identity of frame as first datagram idx
        send_datagrams[0].header.idx = idx;

        var frame = telegram.EthernetFrame.init(
            Port.get_ethernet_header(),
            telegram.EtherCATFrame.init(send_datagrams),
        );

        var out_buf: [telegram.max_frame_length]u8 = undefined;
        const n_bytes = frame.serialize(&out_buf) catch |err| switch (err) {
            error.NoSpaceLeft => return error.FrameSerializationFailure,
        };
        const out = out_buf[0..n_bytes];
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
            error.SocketError => {
                return error.SocketError;
            },
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
                    return error.SocketError;
                },
            };
        }
        if (n_bytes_read == 0) {
            std.log.debug("no bytes to read", .{});
            return;
        }
        const bytes_read: []const u8 = buf[0..n_bytes_read];
        std.log.debug("recv: {x}, len: {}", .{ bytes_read, bytes_read.len });
        const recv_frame_idx = telegram.EthernetFrame.identifyFromBuffer(bytes_read) catch return error.InvalidFrame;
        std.log.debug("identified frame as idx: {}", .{recv_frame_idx});

        switch (self.recv_datagrams_status[recv_frame_idx]) {
            .in_use_receivable => {
                self.recv_datagrams_status_mutex.lock();
                defer self.recv_datagrams_status_mutex.unlock();
                const frame_res = telegram.EthernetFrame.deserialize(bytes_read, self.recv_datagrams[recv_frame_idx]);
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
            .ether_type = .ETHERCAT,
        };
    }

    pub fn send_recv_datagrams(
        self: *Port,
        send_datagrams: []telegram.Datagram,
        timeout_us: u32,
    ) !void {
        assert(send_datagrams.len != 0); // no datagrams
        assert(send_datagrams.len <= 15); // too many datagrams

        var timer = Timer.start() catch |err| switch (err) {
            error.TimerUnsupported => @panic("timer unsupported"),
        };
        var idx: u8 = undefined;
        while (timer.read() < timeout_us * ns_per_us) {
            idx = self.claim_transaction() catch |err| switch (err) {
                error.NoTransactionAvailable => continue,
            };
            break;
        } else {
            return error.NoTransactionAvailableTimeout;
        }
        defer self.release_transaction(idx);

        try self.send_transaction(idx, send_datagrams);

        while (timer.read() < timeout_us * 1000) {
            if (try self.continue_transaction(idx)) {
                return;
            }
        } else {
            return error.RecvTimeout;
        }
    }
};
