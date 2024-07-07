const std = @import("std");
const Mutex = std.Thread.Mutex;
const assert = std.debug.assert;

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
};

const FrameBufferBacker = [telegram.max_frame_length]u8;

const FrameBufferFBS = std.io.FixedBufferStream([]u8);

const FrameBuffer = struct {
    status: FrameStatus = FrameStatus.available,
    idx: u8,
    backer: *FrameBufferBacker,
    fbs: *FrameBufferFBS,
    allocator: std.mem.Allocator,

    fn init(idx: u8, allocator: std.mem.Allocator) !FrameBuffer {
        const backer = try allocator.create(FrameBufferBacker);
        errdefer allocator.free(backer);

        const fbs = try allocator.create(FrameBufferFBS);
        errdefer allocator.free(fbs);

        fbs.* = std.io.fixedBufferStream(backer);

        return FrameBuffer{
            .backer = backer,
            .idx = idx,
            .fbs = fbs,
            .allocator = allocator,
        };
    }
    fn deinit(self: FrameBuffer) void {
        self.allocator.destroy(self.backer);
        self.allocator.destroy(self.fbs);
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
    socket: std.posix.socket_t,
    frames: []FrameBuffer,
    allocator: std.mem.Allocator,

    pub fn init(
        ifname: []const u8,
        allocator: std.mem.Allocator,
        args: PortOptions,
    ) !Port {
        var frames = try allocator.alloc(FrameBuffer, args.max_frame_idx + 1);
        errdefer allocator.free(frames);

        var idx: u8 = 0; // idx = num allocated
        errdefer for (frames[0..idx]) |frame| {
            frame.deinit();
        };
        for (frames) |*frame| {
            frame.* = try FrameBuffer.init(idx, allocator);
            idx += 1;
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
    pub fn deinit(self: Port) void {
        for (self.frames) |frame| {
            frame.deinit();
        }
        self.allocator.free(self.frames);
    }

    /// Non-blocking fetch frame.
    ///
    /// Search frame buffers for the frame, if its not found
    /// do one recv. If not found still, return frameNotFound.
    ///
    /// The caller is expected to attempt multiple times to get
    /// the frame, for a long as they wish.
    //pub fn fetch_frame(self: Port, idx: u8) error{frameNotFound}!*FrameBuffer {}

    /// Send a frame.
    ///
    /// Returns the idx of the frame for later retreival
    /// by fetch_frame.
    ///
    /// Returns idx of sent frame
    // pub fn send_frame(self: Port, frame: telegram.EthernetFrame) !u8 {
    //     const frame_buffer: *FrameBuffer = self.claim_frame();
    //     const header = telegram.EthernetHeader{
    //         .dest_mac = std.mem.nativeToBig(u48, MAC_BROADCAST),
    //         .src_max = std.mem.nativeToBig(u48, MAC_SOURCE),
    //         .ether_type = std.mem.nativeToBig(u32, ETH_P_ETHERCAT),
    //     };
    //     @memcpy(frame_buffer.tx[0..@bitSizeOf(header)], std.mem.asBytes(header));
    //     @memcpy(frame_buffer.tx[@sizeOf(header)..], data);
    //     self.send_mutex.lock();
    //     defer self.send_mutex.unlock();
    //     try std.posix.write(self.socket, frame_buffer.tx);
    // }

    /// Claim a frame buffer.
    fn claim_frame(self: Port) error{noFrameBufferAvailable}!*FrameBuffer {
        self.frame_status_mutex.lock();
        defer self.frame_status_mutex.unlock();

        for (self.frames) |frame| {
            if (frame.status == FrameStatus.available) {
                frame.status = FrameStatus.in_use;
                return &frame;
            }
        } else {
            return error.noFrameBufferAvailable;
        }
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
