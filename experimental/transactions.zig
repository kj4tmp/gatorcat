//! Design of a concurrent (thread-safe) network transaction queue for real-time communication.
//!
//! This is a technical article written as a zig file. The file can be tested with `zig test this-file.zig`.

const std = @import("std");
const assert = std.debug.assert;

// An interface for communicating over a network adapter in a real-time context is required.
//
// The network adapter ("LinkLayer") is provided as a VTable with `send()` and `recv()` methods. Critically, two tasks must not attempt to
// `send` at the same time. However, `send` and `recv` may happen simultaneously.
// The performance cost of a VTable is accepted since the maximum number of VTable traversals is fixed and low, and we would like
// to provide an interface that can be later be easily extended by users on embedded systems.

// The VTable for the LinkLayer Looks like this:

const telegram = struct {
    pub const max_frame_length = 1514;
};

/// Interface for networking hardware
pub const LinkLayer = struct {
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
    pub fn send(self: LinkLayer, data: []const u8) anyerror!void {
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
    pub fn recv(self: LinkLayer, out: []u8) anyerror!usize {
        return try self.vtable.recv(self.ptr, out);
    }
};

// And an example implementation for Raw Socket on linux:

/// Raw socket implementation for LinkLayer
pub const RawSocket = struct {
    send_mutex: std.Thread.Mutex = .{},
    recv_mutex: std.Thread.Mutex = .{},
    socket: std.posix.socket_t,

    pub fn init(
        ifname: [:0]const u8,
    ) !RawSocket {
        if (ifname.len > std.posix.IFNAMESIZE - 1) return error.InterfaceNameTooLong;
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
        ifr.ifru.flags.BROADCAST = true;
        ifr.ifru.flags.PROMISC = true;
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

    pub fn linkLayer(self: *RawSocket) LinkLayer {
        return LinkLayer{
            .ptr = self,
            .vtable = &.{ .send = send, .recv = recv },
        };
    }
};

// Lets estimate the number of VTable traversals required to saturate the link bandwidth
// and prove to ourselves that we are OK with using a VTable.

test "link layer saturation math" {

    // We will estimate the number of times we must traverse the VTable
    // by counting how many times we must call `send` and `recv` on the LinkLayer.
    // Each call to `send` counts as one "VTable traversal".

    // The link bandwidth is 100 MBit each direction (send and recv).
    const link_bandwidth: f64 = 100_000_000;

    // There will be at most two ethernet ports in use by a single application.
    const number_of_links: f64 = 2;

    // In a well designed system, each ethernet frame contains as much data as possible.
    // We will consider the ethernet frames to be well-designed and contain about 1500 bytes.
    const bits_per_frame: f64 = 1500 * 8;

    const sends_per_second: f64 = link_bandwidth * number_of_links / bits_per_frame;

    // In a well designed implementation, we only call send and recv once per frame.
    const vtable_traversals_per_second: f64 = sends_per_second * 2;

    std.debug.print("vtable_traversals_per_second: {d}\n", .{vtable_traversals_per_second});
    try std.testing.expectEqual(33_333, @as(i64, @intFromFloat(vtable_traversals_per_second)));

    // So we can estimate about 33k vtable traversals per second here. Doesn't seem that bad.
}

// Communication is initiated and fully controlled by the server, called the "maindevice".
// Frames travel in a ring, starting at the maindevice, passing through a number of clients, called "subdevices", and returning to the maindevice. The maindevice
// is the only one sending frames. Subdevices modify the frames as they travel through the rings with new zero propagation delays thanks to ASICs in the subdevices.

// The fundamental atomic unit of work is a "transaction". In async terms, this could be called a completion, or maybe an item in a queue.
// A transaction is an EtherCAT "datagram", sent by the maindevice, processed by a subdevices, and returned to the maindevice.

// Multiple datagrams can fit in a single ethernet frame. Ideally, we would pack as many datagrams as possible into a single
// ethernet frame before calling `send` to minimize system calls. If we were really cool, we would use io-uring to reduce the number
// of system calls even further, but thats outside the scope of this discussion.

// The structure of the datagram is important and will influence our implementation:

/// Datagram
///
/// The IEC standard specifies the different commands
/// as different structures. However, the structure are all
/// very similar to they are combined here as one datagram.
///
/// The ETG standards appear to do combine them all too.
///
/// The only difference between the different commands is the addressing
/// scheme. They all have the same size.
///
/// Ref: IEC 61158-4-12:2019 5.4.1.2
pub const Datagram = struct {
    header: Header,
    data: []const u8,
    wkc: u16,

    pub const Header = packed struct(u80) {
        /// service command, APRD etc.
        command: Command,
        /// used by maindevice to identify duplicate or lost datagrams
        idx: u8 = 0,
        /// auto-increment, configured station, or logical address
        /// when position addressing
        address: u32,
        /// length of following data, in bytes, not including wkc
        length: u11,
        /// reserved, 0
        reserved: u3 = 0,
        /// true when frame has circulated at least once, else false
        circulating: bool,
        /// multiple datagrams, true when more datagrams follow, else false
        next: bool,
        /// EtherCAT event request register of all subdevices combined with
        /// a logical OR. Two byte bitmask (IEC 61131-3 WORD)
        irq: u16,
    };

    pub const Command = enum(u8) {
        /// No operation.
        /// The subdevice ignores the command.
        NOP = 0x00,
        /// Auto increment physical read.
        /// A subdevice increments the address.
        /// A subdevice writes the data it has read to the EtherCAT datagram
        /// if the address received is zero.
        APRD,
        /// Auto increment physical write.
        /// A subdevice increments the address.
        /// A subdevice writes data to a memory area if the address received is zero.
        APWR,
        /// Auto increment physical read write.
        /// A subdevice increments the address.
        /// A subdevice writes the data it has read to the EtherCAT datagram and writes
        /// the newly acquired data to the same memory area if the received address is zero.
        APRW,
        /// Configured address physical read.
        /// A subdevice writes the data it has read to the EtherCAT datagram if its subdevice
        /// address matches one of the addresses configured in the datagram.
        FPRD,
        /// Configured address physical write.
        /// A subdevice writes data to a memory area if its subdevice address matches one
        /// of the addresses configured in the datagram.
        FPWR,
        /// Configured address physical read write.
        /// A subdevice writes the data it has read to the EtherCAT datagram and writes
        /// the newly acquired data to the same memory area if its subdevice address matches
        /// one of the addresses configured in the datagram.
        FPRW,
        /// Broadcast read.
        /// All subdevices write a logical OR of the data from the memory area and the data
        /// from the EtherCAT datagram to the EtherCAT datagram. All subdevices increment the
        /// position field.
        BRD,
        /// Broadcast write.
        /// All subdevices write data to a memory area. All subdevices increment the position field.
        BWR,
        /// Broadcast read write.
        /// All subdevices write a logical OR of the data from the memory area and the data from the
        /// EtherCAT datagram to the EtherCAT datagram; all subdevices write data to the memory area.
        /// BRW is typically not used. All subdevices increment the position field.
        BRW,
        /// Logical memory read.
        /// A subdevice writes data it has read to the EtherCAT datagram if the address received
        /// matches one of the FMMU areas configured for reading.
        LRD,
        /// Logical memory write.
        /// Subdevices write data to their memory area if the address received matches one of
        /// the FMMU areas configured for writing.
        LWR,
        /// Logical memory read write.
        /// A subdevice writes data it has read to the EtherCAT datagram if the address received
        /// matches one of the FMMU areas configured for reading. Subdevices write data to their memory area
        /// if the address received matches one of the FMMU areas configured for writing.
        LRW,
        /// Auto increment physical read multiple write.
        /// A subdevice increments the address field. A subdevice writes data it has read to the EtherCAT
        /// datagram when the address received is zero, otherwise it writes data to the memory area.
        ARMW,
        /// Configured address physical read multiple write.
        FRMW,
        /// Never serialize an unnamed value. This is here only to help ensure we
        /// handle invalid data correctly on deserialization.
        _,
    };
};

// The main thing to notice about the structure of the datagram is that it has a fixed length header before variable length encapsulated data.

// The concurrency model selected is threading. I would have liked to use async but its just too hard right now in zig.
// I'm a systems programmer using a systems programming language, so lets use what the linux wizards have given us!
// The host OS (PREEMPT_RT linux) gives me a means of real-time scheduling, which I plan to take full advantage of.
// Even though I have selected threading, the implementation must still be capable of running in a single threaded manner
// to support use cases in embedded contexts or a simplified user experience.

// The user application will want to concurrently run many transactions but with predictable latency.
// The network is a ring topology with fixed, predictable propagation delays. Frames will always take the same amount if time to traverse
// the ring thanks to ASICs in the subdevices: typically 1 microsecond of propagation delay is accumulated for each subdevice in the ring.
// A typical 200 subdevice ring will have 200 +/- <<1 microseconds of propagation delay.
//
// Typically, one thread will be assigned to a grounp of subdevices. The thread will command its subdevice group using a number of datagrams
// at a regular interval called the cycle time. The cycle time is typically 100 microseconds to 4 milliseconds. Most implementations limit their
// cycle time to the propagation delays, but if you are extra cool you have multiple datagrams travelling the network at once, which allows one to
// command a subdevice at higher rates then the propagation delay would normally allow, kind of like a ping flood.
// The latency (time to react to a stimulus, like a sensor going low) is always limited by the propagation delay though.
// Users like to have multiple threads at different cycle times to conserve the link bandwidth:
//
// 1. Subdevice group 1 (thread 1, real-time priority high) is 64 motor driver subdevices commanded every 1000 us.
// 2. Subdevice group 2 (thread 2, real-time priority low) is 300 valve driver subdevices commanded every 4000 us.
//
// In this manner, the user is able to conserve link bandwidth for subdevices which can be updated less frequently.
//
// Fun fact: the World of Color show at Disneyland is rumored to be controlled by an EtherCAT network.

// Lets return to the datagram structure:

// pub const Header = packed struct(u80) {
//     /// service command, APRD etc.
//     command: Command,
//     /// used by maindevice to identify duplicate or lost datagrams
//     idx: u8 = 0,
//     /// auto-increment, configured station, or logical address
//     /// when position addressing
//     address: u32,
//     ...

// We need to identify datagrams on receipt and deserialize them into appropriate buffers.
// Here are some possible ways we could identify transactions:
//
// 1. use the `idx: u8` field of the header. This only allows us 256 simultaneous transactions.
// 2. use the 'idx: u8' field of only the first datagram in a multi-datagram ethernet frame. This gets use 256*15 simultaneous datagrams and is pretty complicated to implement.
// 3. just use the entire first 64 bits of the datagram header to identify the datagrams. this is pretty simple to implement, and collisions can be resolved by changing the idx.

// Lets mock up the high level API so that multiple threads can work concurrently and link bandwidth usage can be maximized:

// There is one transaction queue per maindevice.
// The transaction queue is shared by multiple threads. One thread per subdevice group.
// The shared state of the transaction queue is protected by a mutex.
// The send and recv functions of the LinkLayer are protected by separate mutexes.
// Each mutex is held for the absolute minimum critical sections of code to maximize
// parallelism.
const TransactionQueue = struct {

    // The first step a thread takes is to reserve transactions.
    // We cannot simply return an error on enqueing. Threads must be assured that they will always be able to enqueue
    // their transactions before beginning their cyclic work. A thread being subject to dynamic memory limits
    // or other congestion is not acceptable.
    pub fn reserveTransaction(thread_id: std.Thread.Id, transaction: ?) void {
        _ = thread_id;
    }

    // Once a thread has reserved a spot in the transaction queue,
    // it can enque the transaction.
    pub fn enqueueTransaction(thread_id: std.Thread.Id, transaction: ?) void {
        _ = thread_id;
    }

    // Once a thread has enqueued their transactions, the thread can send all of them at once.
    // This has the convienient feature that a higher OS priority thread will get to send their
    // transactions first.
    pub fn sendTransactions(thread_id: std.Thread.Id) void {
        _ = thread_id;
    }

    // Once a thread has slept an amount of time (typically slightly more than the expected propagation delay),
    // the thread will attempt to receive the transactions. If the transactions are not yet revceived, they are marked
    // as dropped.
    // Keep in mind that it is possible for one thread to receive the transactions of another thread.
    pub fn recvTransactions() void {}
};

// This implementation has the advantage that the transaction queue has no concept of time.
// However, it has the disadvantage that we cannot call recvTransactions multiple times. We must know
// when we expect the recieve them.

// Open questions
// 1. What data structure actually backs the transaction queue? A hashmap where the keys are thread id + datagram headers 
// and the value are pointers to memory to deserialize transaction results into?
