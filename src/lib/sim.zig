//! Deterministic Simulator for EtherCAT Networks

const std = @import("std");
const assert = std.debug.assert;

const ENI = @import("ENI.zig");
const nic = @import("nic.zig");

pub const Simulator = struct {
    eni: ENI,

    pub fn init(eni: ENI) Simulator {
        return Simulator{
            .eni = eni,
        };
    }
    pub fn tick(self: *Simulator) void {
        _ = self;
    }

    pub fn send(ctx: *anyopaque, bytes: []const u8) std.posix.SendError!void {
        const self: *Simulator = @ptrCast(@alignCast(ctx));
        _ = self;
        _ = bytes;
        unreachable;
    }

    pub fn recv(ctx: *anyopaque, out: []u8) std.posix.RecvFromError!usize {
        const self: *Simulator = @ptrCast(@alignCast(ctx));
        _ = self;
        _ = out;
        unreachable;
    }

    pub fn linkLayer(self: *Simulator) nic.LinkLayer {
        return nic.LinkLayer{
            .ptr = self,
            .vtable = &.{ .send = send, .recv = recv },
        };
    }
};

test {
    std.testing.refAllDecls(@This());
}
