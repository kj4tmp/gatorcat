//! Deterministic Simulator for EtherCAT Networks

const std = @import("std");

const ENI = @import("ENI.zig");
const nic = @import("nic.zig");

pub const Simulator = struct {
    eni: ENI,

    pub fn init(eni: ENI) Simulator {
        return Simulator{
            .eni = eni,
        };
    }
    pub fn tick() void {}
};

test {
    std.testing.refAllDecls(@This());
}
