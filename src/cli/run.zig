const std = @import("std");
const builtin = @import("builtin");

const gcat = @import("gatorcat");

pub const Args = struct {
    ifname: [:0]const u8,
    recv_timeout_us: u32 = 10_000,
    eeprom_timeout_us: u32 = 10_000,
    INIT_timeout_us: u32 = 5_000_000,
    PREOP_timeout_us: u32 = 10_000_000,
    mbx_timeout_us: u32 = 50_000,
    pub const descriptions = .{
        .ifname = "Network interface to use for the bus scan.",
        .recv_timeout_us = "Frame receive timeout in microseconds.",
        .eeprom_timeout_us = "SII EEPROM timeout in microseconds.",
        .INIT_timeout_us = "state transition to INIT timeout in microseconds.",
    };
};

pub fn run(allocator: std.mem.Allocator, args: Args) !void {
    _ = args;
    _ = allocator;
}
