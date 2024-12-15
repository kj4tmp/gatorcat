const std = @import("std");
const assert = std.debug.assert;

const nic = @import("nic.zig");
const telegram = @import("telegram.zig");
const wire = @import("wire.zig");

const Port = @This();

recv_frames_status_mutex: std.Thread.Mutex = .{},
recv_frames: [max_frames]*telegram.EtherCATFrame = undefined,
recv_frames_status: [max_frames]FrameStatus = [_]FrameStatus{FrameStatus.available} ** max_frames,
last_used_idx: u8 = 0,
link_layer: nic.LinkLayer,
settings: Settings,

pub const Settings = struct {
    source_mac_address: u48 = 0xffff_ffff_ffff,
    dest_mac_address: u48 = 0xABCD_EF12_3456,
};

pub const max_frames: u9 = 256;

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

pub fn init(link_layer: nic.LinkLayer, settings: Settings) Port {
    return Port{ .link_layer = link_layer, .settings = settings };
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

    // type system guarantees frames will serialize
    const n_bytes = frame.serialize(idx, &out_buf) catch |err| switch (err) {
        error.NoSpaceLeft => unreachable,
    };
    const out = out_buf[0..n_bytes];

    // TODO: handle partial send error
    _ = self.link_layer.send(out) catch return error.LinkError;
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

    frame_size = self.link_layer.recv(&buf) catch |err| switch (err) {
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

    var timer = std.time.Timer.start() catch |err| switch (err) {
        error.TimerUnsupported => unreachable,
    };
    var idx: u8 = undefined;
    while (timer.read() < @as(u64, timeout_us) * std.time.ns_per_us) {
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
    try self.nop(1, timeout_us);
}

fn sendDatagram(
    self: *Port,
    command: telegram.Command,
    address: u32,
    data: []u8,
    timeout_us: u32,
) !u16 {
    assert(data.len <= telegram.Datagram.max_data_length);

    var datagrams: [1]telegram.Datagram = .{
        telegram.Datagram.init(
            command,
            address,
            false,
            data,
        ),
    };
    var frame = telegram.EtherCATFrame.init(&datagrams) catch |err| switch (err) {
        error.Overflow => unreachable,
        error.NoSpaceLeft => unreachable,
    };
    self.send_recv_frame(
        &frame,
        &frame,
        timeout_us,
    ) catch |err| switch (err) {
        // only one datagram so it should fit
        error.FrameSerializationFailure => unreachable,
        error.RecvTimeout => return error.RecvTimeout,
        error.LinkError => return error.LinkError,
        error.CurruptedFrame => return error.CurruptedFrame,
        error.TransactionContention => return error.TransactionContention,
    };
    // checked by telegram.EtherCATFrame.isCurrupted
    assert(data.len == frame.datagrams().slice()[0].data.len);
    @memcpy(data, frame.datagrams().slice()[0].data);
    return frame.datagrams().slice()[0].wkc;
}

/// No operation.
/// The subdevice ignores the command.
pub fn nop(self: *Port, data_size: u16, timeout_us: u32) !void {
    assert(data_size <= telegram.Datagram.max_data_length);
    assert(data_size > 0);
    var zeros = std.mem.zeroes([telegram.Datagram.max_data_length]u8);
    // wkc can be ignored on NOP, it is always zero
    _ = try sendDatagram(
        self,
        telegram.Command.NOP,
        0,
        zeros[0..data_size],
        timeout_us,
    );
}

/// Auto increment physical read.
/// A subdevice increments the address.
/// A subdevice writes the data it has read to the EtherCAT datagram
/// if the address received is zero.
pub fn aprd(
    self: *Port,
    address: telegram.PositionAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        self,
        telegram.Command.APRD,
        @bitCast(address),
        data,
        timeout_us,
    );
}

/// Auto-increment physical read a packable type
pub fn aprdPack(
    self: *Port,
    comptime packed_type: type,
    address: telegram.PositionAddress,
    timeout_us: u32,
) !struct { ps: packed_type, wkc: u16 } {
    var data = wire.zerosFromPack(packed_type);
    const wkc = try aprd(self, address, &data, timeout_us);
    return .{ .ps = wire.packFromECat(packed_type, data), .wkc = wkc };
}

/// Auto increment physical write.
/// A subdevice increments the address.
/// A subdevice writes data to a memory area if the address received is zero.
pub fn apwr(
    self: *Port,
    address: telegram.PositionAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        self,
        telegram.Command.APWR,
        @bitCast(address),
        data,
        timeout_us,
    );
}

pub fn apwrPackWkc(
    self: *Port,
    packed_type: anytype,
    address: telegram.PositionAddress,
    timeout_us: u32,
    expected_wkc: u16,
) !void {
    var data = wire.eCatFromPack(packed_type);
    const wkc = try apwr(self, address, &data, timeout_us);
    if (wkc != expected_wkc) return error.Wkc;
}

/// Auto-increment physical write a packable type
pub fn apwrPack(
    self: *Port,
    packed_type: anytype,
    address: telegram.PositionAddress,
    timeout_us: u32,
) !u16 {
    var data = wire.eCatFromPack(packed_type);
    const wkc = try apwr(self, address, &data, timeout_us);
    return wkc;
}

/// Auto increment physical read write.
/// A subdevice increments the address.
/// A subdevice writes the data it has read to the EtherCAT datagram and writes
/// the newly acquired data to the same memory area if the received address is zero.
pub fn aprw(
    self: *Port,
    address: telegram.PositionAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        self,
        telegram.Command.APRW,
        @bitCast(address),
        data,
        timeout_us,
    );
}

/// Auto-increment physical read-write a packable type
pub fn aprwPack(
    self: *Port,
    packed_type: anytype,
    address: telegram.PositionAddress,
    timeout_us: u32,
) !struct { ps: @TypeOf(packed_type), wkc: u16 } {
    var data = wire.eCatFromPack(packed_type);
    const wkc = try aprw(self, address, &data, timeout_us);
    return .{ .ps = wire.packFromECat(@TypeOf(packed_type), data), .wkc = wkc };
}

/// Configured address physical read.
/// A subdevice writes the data it has read to the EtherCAT datagram if its subdevice
/// address matches one of the addresses configured in the datagram.
pub fn fprd(
    self: *Port,
    address: telegram.StationAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        self,
        telegram.Command.FPRD,
        @bitCast(address),
        data,
        timeout_us,
    );
}

pub fn fprdWkc(
    self: *Port,
    address: telegram.StationAddress,
    data: []u8,
    timeout_us: u32,
    expected_wkc: u16,
) !void {
    const wkc = try fprd(self, address, data, timeout_us);
    if (wkc != expected_wkc) return error.Wkc;
}

/// Configured address physical read a packable type
pub fn fprdPack(
    self: *Port,
    comptime packed_type: type,
    address: telegram.StationAddress,
    timeout_us: u32,
) !struct { ps: packed_type, wkc: u16 } {
    var data = wire.zerosFromPack(packed_type);
    const wkc = try fprd(self, address, &data, timeout_us);
    return .{ .ps = wire.packFromECat(packed_type, data), .wkc = wkc };
}

/// Configured address physical read a packable type, expect wkc
pub fn fprdPackWkc(
    self: *Port,
    comptime packed_type: type,
    address: telegram.StationAddress,
    timeout_us: u32,
    expected_wkc: u16,
) !packed_type {
    const res = try fprdPack(
        self,
        packed_type,
        address,
        timeout_us,
    );
    if (res.wkc != expected_wkc) {
        return error.Wkc;
    }
    return res.ps;
}

/// Configured address physical write.
/// A subdevice writes data to a memory area if its subdevice address matches one
/// of the addresses configured in the datagram.
pub fn fpwr(
    self: *Port,
    address: telegram.StationAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        self,
        telegram.Command.FPWR,
        @bitCast(address),
        data,
        timeout_us,
    );
}

pub fn fpwrWkc(
    self: *Port,
    address: telegram.StationAddress,
    data: []u8,
    timeout_us: u32,
    expected_wkc: u16,
) !void {
    const wkc = try fpwr(self, address, data, timeout_us);
    if (wkc != expected_wkc) return error.Wkc;
}

/// Configured address physical write a packable type
pub fn fpwrPack(
    self: *Port,
    packed_type: anytype,
    address: telegram.StationAddress,
    timeout_us: u32,
) !u16 {
    var data = wire.eCatFromPack(packed_type);
    const wkc = try fpwr(self, address, &data, timeout_us);
    return wkc;
}

pub fn fpwrPackWkc(
    self: *Port,
    packed_type: anytype,
    address: telegram.StationAddress,
    timeout_us: u32,
    expected_wkc: u16,
) !void {
    const wkc = try fpwrPack(self, packed_type, address, timeout_us);
    if (wkc != expected_wkc) return error.Wkc;
}

/// Configured address physical read write.
/// A subdevice writes the data it has read to the EtherCAT datagram and writes
/// the newly acquired data to the same memory area if its subdevice address matches
/// one of the addresses configured in the datagram.
pub fn fprw(
    self: *Port,
    address: telegram.StationAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        self,
        telegram.Command.FPRW,
        @bitCast(address),
        data,
        timeout_us,
    );
}

/// Configured address physical read-write a packable type
pub fn fprwPack(
    self: *Port,
    packed_type: anytype,
    address: telegram.StationAddress,
    timeout_us: u32,
) !struct { ps: @TypeOf(packed_type), wkc: u16 } {
    var data = wire.eCatFromPack(packed_type);
    const wkc = try fprw(self, address, &data, timeout_us);
    return .{ .ps = wire.packFromECat(@TypeOf(packed_type), data), .wkc = wkc };
}

/// Broadcast read.
/// All subdevices write a logical OR of the data from the memory area and the data
/// from the EtherCAT datagram to the EtherCAT datagram. All subdevices increment the
/// position field.
pub fn brd(
    self: *Port,
    address: telegram.PositionAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        self,
        telegram.Command.BRD,
        @bitCast(address),
        data,
        timeout_us,
    );
}

/// Broadcast read a packable type
pub fn brdPack(
    self: *Port,
    comptime packed_type: type,
    address: telegram.PositionAddress,
    timeout_us: u32,
) !struct { ps: packed_type, wkc: u16 } {
    var data = wire.zerosFromPack(packed_type);
    const wkc = try brd(self, address, &data, timeout_us);
    return .{ .ps = wire.packFromECat(packed_type, data), .wkc = wkc };
}

/// Broadcast write.
/// All subdevices write data to a memory area. All subdevices increment the position field.
pub fn bwr(
    self: *Port,
    address: telegram.PositionAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        self,
        telegram.Command.BWR,
        @bitCast(address),
        data,
        timeout_us,
    );
}

pub fn bwrPackWkc(
    self: *Port,
    packed_type: anytype,
    address: telegram.PositionAddress,
    timeout_us: u32,
    expected_wkc: u16,
) !void {
    var data = wire.eCatFromPack(packed_type);
    const wkc = try bwr(self, address, &data, timeout_us);
    if (wkc != expected_wkc) return error.Wkc;
}

/// Broadcast write a packable type
pub fn bwrPack(
    self: *Port,
    packed_type: anytype,
    address: telegram.PositionAddress,
    timeout_us: u32,
) !u16 {
    var data = wire.eCatFromPack(packed_type);
    const wkc = try bwr(self, address, &data, timeout_us);
    return wkc;
}

/// Broadcast read write.
/// All subdevices write a logical OR of the data from the memory area and the data from the
/// EtherCAT datagram to the EtherCAT datagram; all subdevices write data to the memory area.
/// BRW is typically not used. All subdevices increment the position field.
pub fn brw(
    self: *Port,
    address: telegram.PositionAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        self,
        telegram.Command.BRW,
        @bitCast(address),
        data,
        timeout_us,
    );
}

/// Broadcast read-write a packable type
pub fn brwPack(
    self: *Port,
    packed_type: anytype,
    address: telegram.PositionAddress,
    timeout_us: u32,
) !struct { ps: @TypeOf(packed_type), wkc: u16 } {
    var data = wire.eCatFromPack(packed_type);
    const wkc = try brw(self, address, &data, timeout_us);
    return .{ .ps = wire.packFromECat(@TypeOf(packed_type), data), .wkc = wkc };
}

/// Logical memory read.
/// A subdevice writes data it has read to the EtherCAT datagram if the address received
/// matches one of the FMMU areas configured for reading.
pub fn lrd(
    self: *Port,
    address: telegram.LogicalAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        self,
        telegram.Command.LRD,
        @bitCast(address),
        data,
        timeout_us,
    );
}

/// Logical memory write.
/// SubDevices write data to their memory area if the address received matches one of
/// the FMMU areas configured for writing.
pub fn lwr(
    self: *Port,
    address: telegram.LogicalAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        self,
        telegram.Command.LWR,
        @bitCast(address),
        data,
        timeout_us,
    );
}

/// Logical memory read write.
/// A subdevice writes data it has read to the EtherCAT datagram if the address received
/// matches one of the FMMU areas configured for reading. SubDevices write data to their memory area
/// if the address received matches one of the FMMU areas configured for writing.
pub fn lrw(
    self: *Port,
    address: telegram.LogicalAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        self,
        telegram.Command.LRW,
        @bitCast(address),
        data,
        timeout_us,
    );
}

/// Auto increment physical read multiple write.
/// A subdevice increments the address field. A subdevice writes data it has read to the EtherCAT
/// datagram when the address received is zero, otherwise it writes data to the memory area.
pub fn armw(
    self: *Port,
    address: telegram.PositionAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        self,
        telegram.Command.ARMW,
        @bitCast(address),
        data,
        timeout_us,
    );
}

/// Configured address physical read multiple write.
pub fn frmw(
    self: *Port,
    address: telegram.StationAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        self,
        telegram.Command.FRMW,
        @bitCast(address),
        data,
        timeout_us,
    );
}
