const std = @import("std");
const lossyCast = std.math.lossyCast;
const Mutex = std.Thread.Mutex;
const assert = std.debug.assert;
const Timer = std.time.Timer;
const ns_per_us = std.time.ns_per_us;

const commands = @import("commands.zig");
const telegram = @import("telegram.zig");

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
    settings: Settings,

    pub const Settings = struct {
        source_mac_address: u48 = 0xffff_ffff_ffff,
        dest_mac_address: u48 = 0xABCD_EF12_3456,
    };

    pub fn init(network_adapter: NetworkAdapter, settings: Settings) Port {
        return Port{ .network_adapter = network_adapter, .settings = settings };
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
            .{
                .dest_mac = self.settings.dest_mac_address,
                .src_mac = self.settings.source_mac_address,
                .ether_type = .ETHERCAT,
            },
            send_frame.*,
        );

        var out_buf: [telegram.max_frame_length]u8 = undefined;
        const n_bytes = frame.serialize(idx, &out_buf) catch |err| switch (err) {
            error.NoSpaceLeft => return error.FrameSerializationFailure,
        };
        const out = out_buf[0..n_bytes];

        // TODO: handle partial send error
        _ = self.network_adapter.send(out) catch return error.LinkError;
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
        var frame_size: usize = 0;

        frame_size = self.network_adapter.recv(&buf) catch |err| switch (err) {
            error.WouldBlock => return error.FrameNotFound,
            else => {
                std.log.err("Socket error: {}", .{err});
                return error.LinkError;
            },
        };
        if (frame_size == 0) return;
        if (frame_size > telegram.max_frame_length) return error.InvalidFrame;

        assert(frame_size <= telegram.max_frame_length);
        const bytes_recv: []const u8 = buf[0..frame_size];
        const recv_frame_idx = telegram.EthernetFrame.identifyFromBuffer(bytes_recv) catch return error.InvalidFrame;

        switch (self.recv_frames_status[recv_frame_idx]) {
            .in_use_receivable => {
                self.recv_frames_status_mutex.lock();
                defer self.recv_frames_status_mutex.unlock();
                const frame_res = telegram.EthernetFrame.deserialize(bytes_recv);
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
        try commands.nop(self, timeout_us);
    }

    pub const max_frames: u9 = 256;
};

/// Interface for networking hardware
pub const NetworkAdapter = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        send: *const fn (ctx: *anyopaque, data: []const u8) anyerror!void,
        recv: *const fn (ctx: *anyopaque, out: []u8) anyerror!usize,
    };

    /// Send data on the wire.
    /// Sent data must include the ethernet header and not the FCS.
    /// Sent data must be 1 frame and less than maximum allowable frame length.
    /// Must not partially send data, if the data cannot be transmitted atomically,
    /// an error must be returned.
    ///
    /// Returns error on failure, else void.
    ///
    /// This is similar to the behavior of send() in linux on a raw
    /// socket.
    ///
    /// warning: implementation must be thread-safe.
    pub fn send(self: NetworkAdapter, data: []const u8) anyerror!void {
        assert(data.len <= telegram.max_frame_length);
        return try self.vtable.send(self.ptr, data);
    }

    /// Receive data from the wire.
    /// Received data must include ethernet header and not the FCS.
    /// Receive up to 1 frame of data to the out buffer.
    /// Returns the size of the frame or zero when there is no data,
    /// regardless of the size of the out buffer.
    /// Data in the frame beyond the size of the out buffer is discarded.
    ///
    /// This is similar to the behavior of recv() in linux on a raw
    /// socket with MSG_TRUNC enabled.
    ///
    /// warning: implementation must be thread-safe.
    pub fn recv(self: NetworkAdapter, out: []u8) anyerror!usize {
        return try self.vtable.recv(self.ptr, out);
    }
};

/// Raw socket implementation for NetworkAdapter
pub const RawSocket = struct {
    send_mutex: Mutex = .{},
    recv_mutex: Mutex = .{},
    socket: std.posix.socket_t,

    pub fn init(
        ifname: []const u8,
    ) !RawSocket {
        assert(ifname.len <= std.posix.IFNAMESIZE - 1); // ifname too long
        const ETH_P_ETHERCAT = @intFromEnum(telegram.EtherType.ETHERCAT);
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

        var rval = std.posix.errno(std.os.linux.ioctl(socket, std.os.linux.SIOCGIFFLAGS, @intFromPtr(&ifr)));
        switch (rval) {
            .SUCCESS => {},
            else => {
                return error.nicError;
            },
        }
        const IFF_PROMISC = 256;
        const IFF_BROADCAST = 2;
        ifr.ifru.flags = ifr.ifru.flags | IFF_BROADCAST | IFF_PROMISC;
        rval = std.posix.errno(std.os.linux.ioctl(socket, std.os.linux.SIOCSIFFLAGS, @intFromPtr(&ifr)));
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

    pub fn send(ctx: *anyopaque, bytes: []const u8) std.posix.SendError!void {
        const self: *RawSocket = @ptrCast(@alignCast(ctx));
        self.send_mutex.lock();
        defer self.send_mutex.unlock();
        _ = try std.posix.send(self.socket, bytes, 0);
    }

    pub fn recv(ctx: *anyopaque, out: []u8) std.posix.RecvFromError!usize {
        const self: *RawSocket = @ptrCast(@alignCast(ctx));
        self.recv_mutex.lock();
        defer self.recv_mutex.unlock();
        return try std.posix.recv(self.socket, out, std.posix.MSG.TRUNC);
    }

    pub fn networkAdapter(self: *RawSocket) NetworkAdapter {
        return NetworkAdapter{
            .ptr = self,
            .vtable = &.{ .send = send, .recv = recv },
        };
    }
};

const npcap = @cImport({
    @cInclude("pcap.h");
});

var pcap_errbuf: [npcap.PCAP_ERRBUF_SIZE]u8 = [_]u8{0} ** npcap.PCAP_ERRBUF_SIZE;

pub const WindowsRawSocket = struct {
    send_mutex: Mutex = .{},
    recv_mutex: Mutex = .{},
    socket: *npcap.struct_pcap,

    pub fn init(ifname: [:0]const u8) !WindowsRawSocket {
        const socket = npcap.pcap_open(ifname, 65536, npcap.PCAP_OPENFLAG_PROMISCUOUS |
            npcap.PCAP_OPENFLAG_MAX_RESPONSIVENESS |
            npcap.PCAP_OPENFLAG_NOCAPTURE_LOCAL, -1, null, &pcap_errbuf) orelse {
            std.log.err("Failed to open interface {s}, npcap error: {s}", .{ ifname, pcap_errbuf });
            return error.FailedToOpenInterface;
        };

        return WindowsRawSocket{
            .socket = socket,
        };
    }

    pub fn send(ctx: *anyopaque, bytes: []const u8) std.posix.SendError!void {
        const self: *WindowsRawSocket = @ptrCast(@alignCast(ctx));
        self.send_mutex.lock();
        defer self.send_mutex.unlock();
        const result = npcap.pcap_sendpacket(self.socket, bytes.ptr, @intCast(bytes.len));
        if (result == npcap.PCAP_ERROR) return error.NetworkSubsystemFailed;
    }

    pub fn recv(ctx: *anyopaque, out: []u8) std.posix.RecvFromError!usize {
        const self: *WindowsRawSocket = @ptrCast(@alignCast(ctx));
        self.recv_mutex.lock();
        defer self.recv_mutex.unlock();
        var packet_header_ptr: [*c]npcap.pcap_pkthdr = undefined;
        var packet_data_ptr: [*c]const u8 = undefined;
        const result = npcap.pcap_next_ex(self.socket, &packet_header_ptr, &packet_data_ptr);
        if (result == 0) return 0;
        if (result != 1) return error.NetworkSubsystemFailed;
        var fbs = std.io.fixedBufferStream(out);
        const writer = fbs.writer();

        const bytes_received = packet_header_ptr.*.len;
        if (bytes_received == 0) return 0;
        writer.writeAll(packet_data_ptr[0..bytes_received]) catch |err| switch (err) {
            error.NoSpaceLeft => return @intCast(bytes_received),
        };
        return @intCast(bytes_received);
    }

    pub fn networkAdapter(self: *WindowsRawSocket) NetworkAdapter {
        return NetworkAdapter{
            .ptr = self,
            .vtable = &.{ .send = send, .recv = recv },
        };
    }

    pub fn deinit(self: WindowsRawSocket) void {
        npcap.pcap_close(self.socket);
    }
};

test {
    std.testing.refAllDecls(@This());
}
