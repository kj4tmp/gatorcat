const std = @import("std");

const telegram = @import("telegram.zig");

const TransactionPool = @This();

pool: std.AutoHashMap(comptime K: type, comptime V: type)
last_idx: u8,
std.ArrayHashMap(comptime K: type, comptime V: type, comptime Context: type, comptime store_hash: bool)

pub fn init(items: []?Item) TransactionPool {
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
