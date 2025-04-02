const std = @import("std");
const assert = std.debug.assert;

const telegram = @import("telegram.zig");
const wire = @import("wire.zig");

const FrameBuilder = @This();

frame: telegram.EtherCATFrame = telegram.EtherCATFrame.empty,

pub fn reset(self: *FrameBuilder) void {
    self.* = FrameBuilder{};
}

pub fn dumpFrame(self: *FrameBuilder) telegram.EtherCATFrame {
    assert(self.frame.portable_datagrams.len > 0);
    return self.frame;
}

pub fn datagramDataSpaceRemaining(self: *FrameBuilder) u11 {
    return telegram.EtherCATFrame.max_datagrams_length -
        self.frame.header.length -|
        telegram.Datagram.data_overhead;
}

pub fn appendDatagram(self: *FrameBuilder, dgram: telegram.Datagram) error{NoSpaceLeft}!void {
    var fbs = std.io.fixedBufferStream(&self.frame.data_store);
    const n_datagrams = self.frame.portable_datagrams.slice().len;
    for (self.frame.datagrams().slice()) |datagram| {
        assert(datagram.data.len > 0); // zero length datagrams are not supported
    }
    if (n_datagrams > 0) {
        try fbs.seekBy(self.frame.portable_datagrams.slice()[n_datagrams - 1].data_end);
    }
    const start_pos = try fbs.getPos();
    try fbs.writer().writeAll(dgram.data);
    self.frame.portable_datagrams.append(
        telegram.EtherCATFrame.PortableDatagram.init(dgram, @intCast(start_pos)),
    ) catch |err| switch (err) {
        error.Overflow => return error.NoSpaceLeft,
    };
    self.updateCalculatedFields();
    assert(self.datagramDataIsPacked());
}

pub fn appendBrd(
    self: *FrameBuilder,
    address: telegram.PositionAddress,
    data: []u8,
) error{NoSpaceLeft}!void {
    try self.appendDatagram(telegram.Datagram.init(.BRD, @bitCast(address), false, data));
}

pub fn appendBrdPack(
    self: *FrameBuilder,
    comptime packed_type: type,
    address: telegram.PositionAddress,
) error{NoSpaceLeft}!void {
    var data = wire.zerosFromPack(packed_type);
    try self.appendBrd(address, &data);
}

pub fn appendLrd(
    self: *FrameBuilder,
    address: telegram.LogicalAddress,
    data: []u8,
) error{NoSpaceLeft}!void {
    try self.appendDatagram(telegram.Datagram.init(.LRD, @bitCast(address), false, data));
}

pub fn appendLwr(
    self: *FrameBuilder,
    address: telegram.LogicalAddress,
    data: []u8,
) error{NoSpaceLeft}!void {
    try self.appendDatagram(telegram.Datagram.init(.LWR, @bitCast(address), false, data));
}

pub fn appendLrw(
    self: *FrameBuilder,
    address: telegram.LogicalAddress,
    data: []u8,
) error{NoSpaceLeft}!void {
    try self.appendDatagram(telegram.Datagram.init(.LRW, @bitCast(address), false, data));
}

pub fn appendNop(
    self: *FrameBuilder,
    address: telegram.LogicalAddress,
    data_size: u16,
) error{NoSpaceLeft}!void {
    assert(data_size <= telegram.Datagram.max_data_length);
    assert(data_size > 0);
    var zeros = std.mem.zeroes([telegram.Datagram.max_data_length]u8);
    try self.appendDatagram(telegram.Datagram.init(.NOP, @bitCast(address), false, zeros[0..data_size]));
}

fn datagramDataIsPacked(self: *const FrameBuilder) bool {
    if (self.frame.portable_datagrams.len <= 1) return true;
    for (1..self.frame.portable_datagrams.len) |i| {
        const this_dgram = self.frame.portable_datagrams.slice()[i];
        const last_dgram = self.frame.portable_datagrams.slice()[i - 1];
        if (last_dgram.data_end != this_dgram.data_start or
            last_dgram.data_start == last_dgram.data_end or // zero length datagrams are not supported
            this_dgram.data_start == this_dgram.data_end) // zero length datagrams are not supported
        {
            return false;
        }
    }
    return true;
}

fn updateCalculatedFields(self: *FrameBuilder) void {
    self.updateNexts();
    self.updateLength();
}

fn updateNexts(self: *FrameBuilder) void {
    for (self.frame.portable_datagrams.slice(), 0..) |*datagram, i| {
        if (i == self.frame.portable_datagrams.slice().len - 1) {
            datagram.header.next = false;
            continue;
        }
        datagram.header.next = true;
    }
}

fn updateLength(self: *FrameBuilder) void {
    var new_header_length: u11 = 0;
    for (self.frame.datagrams().slice()) |datagram| {
        new_header_length += datagram.getLength();
    }
    self.frame.header.length = new_header_length;
}

test {
    std.testing.refAllDecls(@This());
}
