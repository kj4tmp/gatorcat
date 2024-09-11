const std = @import("std");
const Timer = std.time.Timer;
const ns_per_us = std.time.ns_per_us;

const esc = @import("esc.zig");
const nic = @import("nic.zig");
const commands = @import("commands.zig");

pub fn setALState(
    port: *nic.Port,
    state: esc.ALStateControl,
    station_address: u16,
    change_timeout_us: u32,
    retries: u32,
    recv_timeout_us: u32,
) !void {
    // request state with ACK
    for (0..retries) |_| {
        const wkc = try commands.fpwrPack(
            port,
            esc.ALControlRegister{
                .state = state,
                .ack = true,
                .request_id = false,
            },
            .{
                .station_address = station_address,
                .offset = @intFromEnum(esc.RegisterMap.AL_control),
            },
            recv_timeout_us,
        );
        if (wkc == 1) {
            break;
        }
    } else {
        return error.Timeout;
    }

    var timer = Timer.start() catch |err| switch (err) {
        error.TimerUnsupported => @panic("timer unsupported"),
    };

    while (timer.read() < change_timeout_us * ns_per_us) {
        const res = try commands.fprdPack(
            port,
            esc.ALStatusRegister,
            .{
                .station_address = station_address,
                .offset = @intFromEnum(esc.RegisterMap.AL_status),
            },
            recv_timeout_us,
        );

        if (res.wkc == 1) {
            const requested: u4 = @intFromEnum(state);
            const actual: u4 = @intFromEnum(res.ps.state);
            if (actual != requested) {
                if (res.ps.err) {
                    std.log.err(
                        "station addr: 0x{x}, refused state change. Actual state: {}, Status Code: {}.",
                        .{ station_address, actual, res.ps.status_code },
                    );
                    return error.StateChangeRefused;
                }
                continue;
            } else {
                return;
            }
        } else {
            continue;
        }
    } else {
        return error.StateChangeTimeout;
    }
    unreachable;
}
