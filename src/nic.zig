const std = @import("std");
const lossyCast = std.math.lossyCast;
const Mutex = std.Thread.Mutex;
const assert = std.debug.assert;

const Timer = std.time.Timer;
const ns_per_us = std.time.ns_per_us;

const telegram = @import("telegram.zig");
const commands = @import("commands.zig");

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
    recv_frames_status_mutex: Mutex = .{},
    recv_frames: [max_frames]*telegram.EtherCATFrame = undefined,
    recv_frames_status: [max_frames]FrameStatus = [_]FrameStatus{FrameStatus.available} ** max_frames,
    last_used_idx: u8 = 0,
    network_adapter: NetworkAdapter,

    pub const max_frames: u9 = 256;

    pub fn init(network_adapter: NetworkAdapter) Port {
        return Port{ .network_adapter = network_adapter };
    }

    /// claim transaction
    ///
    /// claim a transaction idx with the ethercat bus.
    pub fn claim_transaction(self: *Port) error{NoTransactionAvailable}!u8 {
        self.recv_frames_status_mutex.lock();
        defer self.recv_frames_status_mutex.unlock();

        const new_idx = self.last_used_idx +% 1;
        if (self.recv_frames_status[new_idx] == .available) {
            self.recv_frames_status[new_idx] = .in_use;
            self.last_used_idx = new_idx;
            return self.last_used_idx;
        } else return error.NoTransactionAvailable;
    }

    /// Send a transaction with the ethercat bus.
    pub fn send_transaction(self: *Port, idx: u8, send_frame: *const telegram.EtherCATFrame, recv_frame_ptr: *telegram.EtherCATFrame) !void {
        assert(send_frame.datagrams().slice().len > 0); // no datagrams
        assert(send_frame.datagrams().slice().len <= 15); // too many datagrams
        assert(self.recv_frames_status[idx] == FrameStatus.in_use); // should claim transaction first

        // store pointer to where to deserialize frames later
        self.recv_frames[idx] = recv_frame_ptr;

        var frame = telegram.EthernetFrame.init(
            Port.get_ethernet_header(),
            send_frame.*,
        );

        var out_buf: [telegram.max_frame_length]u8 = undefined;
        const n_bytes = frame.serialize(idx, &out_buf) catch |err| switch (err) {
            error.NoSpaceLeft => return error.FrameSerializationFailure,
        };
        const out = out_buf[0..n_bytes];

        // TODO: handle partial write error
        _ = self.network_adapter.write(out) catch return error.LinkError;
        {
            self.recv_frames_status_mutex.lock();
            defer self.recv_frames_status_mutex.unlock();
            self.recv_frames_status[idx] = FrameStatus.in_use_receivable;
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
    /// Returns true when frame has been deserialized successfully.
    pub fn continue_transaction(self: *Port, idx: u8) !bool {
        switch (self.recv_frames_status[idx]) {
            .available => unreachable,
            .in_use => unreachable,
            .in_use_receivable => {},
            .in_use_received => return true,
            .in_use_currupted => return error.CurruptedFrame,
        }
        self.recv_frame() catch |err| switch (err) {
            error.FrameNotFound => {},
            error.LinkError => {
                return error.LinkError;
            },
            error.InvalidFrame => {},
        };
        switch (self.recv_frames_status[idx]) {
            .available => unreachable,
            .in_use => unreachable,
            .in_use_receivable => return false,
            .in_use_received => return true,
            .in_use_currupted => return error.CurruptedFrame,
        }
    }

    fn recv_frame(self: *Port) !void {
        var buf: [telegram.max_frame_length]u8 = undefined;
        var n_bytes_read: usize = 0;

        n_bytes_read = self.network_adapter.read(&buf) catch |err| switch (err) {
            error.WouldBlock => return error.FrameNotFound,
            else => {
                std.log.err("Socket error: {}", .{err});
                return error.LinkError;
            },
        };
        if (n_bytes_read == 0) return;

        const bytes_read: []const u8 = buf[0..n_bytes_read];
        const recv_frame_idx = telegram.EthernetFrame.identifyFromBuffer(bytes_read) catch return error.InvalidFrame;

        switch (self.recv_frames_status[recv_frame_idx]) {
            .in_use_receivable => {
                self.recv_frames_status_mutex.lock();
                defer self.recv_frames_status_mutex.unlock();
                const frame_res = telegram.EthernetFrame.deserialize(bytes_read);
                if (frame_res) |frame| {
                    if (frame.ethercat_frame.isCurrupted(self.recv_frames[recv_frame_idx])) {
                        self.recv_frames_status[recv_frame_idx] = FrameStatus.in_use_currupted;
                        return;
                    }
                    self.recv_frames[recv_frame_idx].* = frame.ethercat_frame;
                    self.recv_frames_status[recv_frame_idx] = FrameStatus.in_use_received;
                } else |err| switch (err) {
                    else => {
                        self.recv_frames_status[recv_frame_idx] = FrameStatus.in_use_currupted;
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
            self.recv_frames_status_mutex.lock();
            defer self.recv_frames_status_mutex.unlock();
            self.recv_frames_status[idx] = FrameStatus.available;
        }
    }

    pub fn get_ethernet_header() telegram.EthernetHeader {
        return telegram.EthernetHeader{
            .dest_mac = MAC_BROADCAST,
            .src_mac = MAC_SOURCE,
            .ether_type = .ETHERCAT,
        };
    }

    pub const SendRecvError = error{
        TransactionContention,
        RecvTimeout,
        FrameSerializationFailure,
        LinkError,
        CurruptedFrame,
    };

    pub fn send_recv_frame(
        self: *Port,
        send_frame: *telegram.EtherCATFrame,
        recv_frame_ptr: *telegram.EtherCATFrame,
        timeout_us: u32,
    ) SendRecvError!void {
        assert(send_frame.datagrams().slice().len != 0); // no datagrams
        assert(send_frame.datagrams().slice().len <= 15); // too many datagrams

        var timer = Timer.start() catch |err| switch (err) {
            error.TimerUnsupported => unreachable,
        };
        var idx: u8 = undefined;
        while (timer.read() < @as(u64, timeout_us) * ns_per_us) {
            idx = self.claim_transaction() catch |err| switch (err) {
                error.NoTransactionAvailable => continue,
            };
            break;
        } else {
            return error.TransactionContention;
        }
        defer self.release_transaction(idx);

        try self.send_transaction(idx, send_frame, recv_frame_ptr);

        while (timer.read() < @as(u64, timeout_us) * 1000) {
            if (try self.continue_transaction(idx)) {
                return;
            }
        } else {
            return error.RecvTimeout;
        }
    }

    /// send and recv a no-op to quickly check if port works and are connected
    pub fn ping(self: *Port, timeout_us: u32) !void {
        _ = try commands.nop(self, timeout_us);
    }
};

/// Interface for networking hardware
pub const NetworkAdapter = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        write: *const fn (ctx: *anyopaque, data: []const u8) anyerror!usize,
        read: *const fn (ctx: *anyopaque, out: []u8) anyerror!usize,
    };

    /// warning: implementation must be thread-safe
    pub fn write(self: NetworkAdapter, data: []const u8) anyerror!usize {
        return try self.vtable.write(self.ptr, data);
    }

    /// warning: implementation must be thread-safe
    pub fn read(self: NetworkAdapter, out: []u8) anyerror!usize {
        return try self.vtable.read(self.ptr, out);
    }
};

/// Raw socket implementation for NetworkAdapter
pub const RawSocket = struct {
    write_mutex: Mutex = .{},
    read_mutex: Mutex = .{},
    socket: std.posix.socket_t,

    pub fn init(
        ifname: []const u8,
    ) !RawSocket {
        assert(ifname.len <= std.posix.IFNAMESIZE - 1); // ifname too long
        const socket: std.posix.socket_t = try std.posix.socket(
            std.posix.AF.PACKET,
            std.posix.SOCK.RAW,
            std.mem.nativeToBig(u32, ETH_P_ETHERCAT),
        );
        var timeout_rcv = std.posix.timeval{
            .sec = 0,
            .usec = 1,
        };
        try std.posix.setsockopt(
            socket,
            std.posix.SOL.SOCKET,
            std.posix.SO.RCVTIMEO,
            std.mem.asBytes(&timeout_rcv),
        );

        var timeout_snd = std.posix.timeval{
            .sec = 0,
            .usec = 1,
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
        return RawSocket{
            .socket = socket,
        };
    }

    pub fn deinit(self: *RawSocket) void {
        std.posix.close(self.socket);
    }

    pub fn write(ctx: *anyopaque, bytes: []const u8) std.posix.WriteError!usize {
        const self: *RawSocket = @ptrCast(@alignCast(ctx));
        self.write_mutex.lock();
        defer self.write_mutex.unlock();
        return try std.posix.write(self.socket, bytes);
    }

    pub fn read(ctx: *anyopaque, out: []u8) std.posix.ReadError!usize {
        const self: *RawSocket = @ptrCast(@alignCast(ctx));
        self.read_mutex.lock();
        defer self.read_mutex.unlock();
        return try std.posix.read(self.socket, out);
    }

    pub fn networkAdapter(self: *RawSocket) NetworkAdapter {
        return NetworkAdapter{
            .ptr = self,
            .vtable = &.{ .write = write, .read = read },
        };
    }
};

test {
    std.testing.refAllDecls(@This());
}
