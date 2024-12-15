const std = @import("std");
const assert = std.debug.assert;

const commands = @import("commands.zig");
const nic = @import("nic.zig");
const telegram = @import("telegram.zig");

const Port = @This();

recv_frames_status_mutex: std.Thread.Mutex = .{},
recv_frames: [max_frames]*telegram.EtherCATFrame = undefined,
recv_frames_status: [max_frames]FrameStatus = [_]FrameStatus{FrameStatus.available} ** max_frames,
last_used_idx: u8 = 0,
network_adapter: nic.LinkLayer,
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

pub fn init(network_adapter: nic.LinkLayer, settings: Settings) Port {
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

    // type system guarantees frames will serialize
    const n_bytes = frame.serialize(idx, &out_buf) catch |err| switch (err) {
        error.NoSpaceLeft => unreachable,
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
    try commands.nop(self, 1, timeout_us);
}
