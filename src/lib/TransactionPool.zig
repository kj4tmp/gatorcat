const std = @import("std");

const telegram = @import("telegram.zig");

const TransactionPool = @This();

const Options = struct {
    num_cyclic_datagrams: u32,
    num_acyclic_datagrams: u32,
};

pub fn init(
    items: []?Item,
) TransactionPool {
    return TransactionPool{ .items = items };
}

pub const Value = struct {
    status: Status,
    sent: *telegram.Datagram,
    receiver: *telegram.Datagram,
    pub const Status = enum {
        sent,
        received,
        currupted,
    };
};
