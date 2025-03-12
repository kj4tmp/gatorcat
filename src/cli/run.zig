//! Run subcommand of the GatorCAT CLI.
//!
//! Intended to exemplify a reasonable default way of doing things with as little configuratiuon as possible.

const std = @import("std");
const builtin = @import("builtin");

const gcat = @import("gatorcat");
const zenoh = @import("zenoh");

pub const Args = struct {
    ifname: [:0]const u8,
    recv_timeout_us: u32 = 10_000,
    eeprom_timeout_us: u32 = 10_000,
    INIT_timeout_us: u32 = 5_000_000,
    PREOP_timeout_us: u32 = 3_000_000,
    SAFEOP_timeout_us: u32 = 10_000_000,
    OP_timeout_us: u32 = 10_000_000,
    mbx_timeout_us: u32 = 50_000,
    cycle_time_us: u32 = 0,
    max_recv_timeouts_before_rescan: u32 = 3,
    zenoh_config_file: ?[:0]const u8 = null,
    pub const descriptions = .{
        .ifname = "Network interface to use for the bus scan.",
        .recv_timeout_us = "Frame receive timeout in microseconds.",
        .eeprom_timeout_us = "SII EEPROM timeout in microseconds.",
        .INIT_timeout_us = "state transition to INIT timeout in microseconds.",
    };
};

pub const RunError = error{
    /// Reached a non-recoverable state and the program should die.
    NonRecoverable,
};

pub fn run(allocator: std.mem.Allocator, args: Args) error{NonRecoverable}!void {
    if (args.zenoh_config_file) |zenoh_config_file| {
        _ = zenoh_config_file;
    }

    var raw_socket = gcat.nic.LinuxRawSocket.init(args.ifname) catch return error.NonRecoverable;
    defer raw_socket.deinit();
    var port = gcat.Port.init(raw_socket.linkLayer(), .{});

    bus_scan: while (true) {
        var ping_timer = std.time.Timer.start() catch @panic("Timer not supported");
        port.ping(args.recv_timeout_us) catch |err| switch (err) {
            error.LinkError => return error.NonRecoverable,
            error.TransactionContention => unreachable, // nobody else is using the port right now
            error.RecvTimeout => {
                std.log.err("Ping failed. No frame returned before the recv timeout. Is anything connected to the specified interface ({s})?", .{args.ifname});
                return error.NonRecoverable;
            },
            error.CurruptedFrame => {
                std.log.err("Ping failed. The ping frame returned modified by the bus. This should not happen. What are you connected to?", .{});
                return error.NonRecoverable;
            },
        };
        std.log.info("Ping returned in {} us.", .{ping_timer.read() / std.time.ns_per_us});

        std.log.info("Scanning bus...", .{});
        var scanner = gcat.Scanner.init(&port, .{
            .eeprom_timeout_us = args.eeprom_timeout_us,
            .mbx_timeout_us = args.mbx_timeout_us,
            .recv_timeout_us = args.recv_timeout_us,
        });
        const num_subdevices = scanner.countSubdevices() catch |err| switch (err) {
            error.LinkError => return error.NonRecoverable,
            error.TransactionContention => unreachable,
            error.RecvTimeout => continue :bus_scan,
            error.CurruptedFrame => return error.NonRecoverable,
        };

        scanner.busInit(args.INIT_timeout_us, num_subdevices) catch |err| switch (err) {
            error.LinkError, error.CurruptedFrame => return error.NonRecoverable,
            error.TransactionContention => unreachable,
            error.RecvTimeout, error.Wkc, error.StateChangeRefused, error.StateChangeTimeout => continue :bus_scan,
        };

        scanner.assignStationAddresses(num_subdevices) catch |err| switch (err) {
            error.LinkError, error.CurruptedFrame => return error.NonRecoverable,
            error.TransactionContention => unreachable,
            error.RecvTimeout, error.Wkc => continue :bus_scan,
        };

        const eni = scanner.readEni(allocator, args.PREOP_timeout_us) catch |err| switch (err) {
            error.LinkError,
            error.Overflow,
            error.NoSpaceLeft,
            error.OutOfMemory,
            error.RecvTimeout,
            error.CurruptedFrame,
            error.TransactionContention,
            error.Wkc,
            error.StateChangeRefused,
            error.StateChangeTimeout,
            error.EndOfStream,
            error.Timeout,
            error.InvalidSubdeviceEEPROM,
            error.UnexpectedSubdevice,
            error.InvalidSII,
            error.InvalidMbxConfiguration,
            error.CoENotSupported,
            error.CoECompleteAccessNotSupported,
            error.Emergency,
            error.NotImplemented,
            error.MbxOutFull,
            error.InvalidMbxContent,
            error.MbxTimeout,
            error.Aborted,
            error.UnexpectedSegment,
            error.UnexpectedNormal,
            error.WrongProtocol,
            error.WrongPackSize,
            error.InvalidSMComms,
            error.InvalidSMChannel,
            error.InvalidSMChannelPDOIndex,
            error.InvalidCoEEntries,
            error.MissedFragment,
            error.InvalidMailboxContent,
            error.InvalidEEPROM,
            error.ObjectDoesNotExist,
            => continue :bus_scan,
        };
        defer eni.deinit();

        var md = gcat.MainDevice.init(
            allocator,
            &port,
            .{ .eeprom_timeout_us = args.eeprom_timeout_us, .mbx_timeout_us = args.mbx_timeout_us, .recv_timeout_us = args.recv_timeout_us },
            eni.value,
        ) catch |err| switch (err) {
            error.OutOfMemory => return error.NonRecoverable,
        };
        defer md.deinit(allocator);

        md.busInit(args.INIT_timeout_us) catch |err| switch (err) {
            error.LinkError, error.CurruptedFrame => return error.NonRecoverable,
            error.TransactionContention => unreachable,
            error.RecvTimeout,
            error.Wkc,
            error.StateChangeRefused,
            error.StateChangeTimeout,
            error.WrongNumberOfSubdevices,
            => continue :bus_scan,
        };

        md.busPreop(args.PREOP_timeout_us) catch |err| switch (err) {
            error.LinkError,
            error.CurruptedFrame,
            error.EndOfStream,
            error.InvalidSubdeviceEEPROM,
            error.InvalidSII,
            error.CoENotSupported,
            error.CoECompleteAccessNotSupported,
            error.Aborted,
            error.UnexpectedSegment,
            error.UnexpectedNormal,
            error.WrongProtocol,
            error.InvalidMbxContent,
            => return error.NonRecoverable,
            error.TransactionContention => unreachable,
            error.Wkc,
            error.StateChangeRefused,
            error.Timeout,
            error.Emergency,
            error.RecvTimeout,
            error.StateChangeTimeout,
            error.InvalidMbxConfiguration,
            error.UnexpectedSubdevice,
            error.NotImplemented,
            error.MbxOutFull, //wtf is this?
            error.MbxTimeout,
            => continue :bus_scan,
        };

        // TODO: wtf jeff reduce the number of errors!
        md.busSafeop(args.SAFEOP_timeout_us) catch |err| switch (err) {
            error.LinkError,
            error.Overflow,
            error.NoSpaceLeft,
            error.CurruptedFrame,
            error.CoENotSupported,
            error.CoECompleteAccessNotSupported,
            error.UnexpectedSegment,
            error.UnexpectedNormal,
            error.WrongProtocol,
            error.InvalidSMChannel,
            error.InvalidSMChannelPDOIndex,
            error.InvalidCoEEntries,
            error.WrongDirection,
            error.SyncManagerNotFound,
            error.RecvTimeout,
            error.Wkc,
            error.StateChangeTimeout,
            error.EndOfStream,
            error.Timeout,
            error.InvalidEEPROM,
            error.InvalidSII,
            error.InvalidMbxConfiguration,
            error.Emergency,
            error.NotImplemented,
            error.MbxOutFull,
            error.InvalidMbxContent,
            error.MbxTimeout,
            error.Aborted,
            error.WrongPackSize, // TODO: wtf is this?
            error.SMAssigns,
            error.OverlappingSM,
            error.NotEnoughFMMUs,
            error.InvalidInputsBitLength,
            error.InvalidOutputsBitLength,
            error.WrongInputsBitLength,
            error.WrongOutputsBitLength,
            => return error.NonRecoverable,
            // => continue :bus_scan,
            error.TransactionContention,
            error.NoTransactionAvailable,
            => unreachable,
        };

        md.busOp(args.OP_timeout_us) catch |err| switch (err) {
            error.LinkError,
            error.CurruptedFrame,
            error.CoENotSupported,
            error.CoECompleteAccessNotSupported,
            error.NotImplemented,
            error.Aborted,
            error.UnexpectedSegment,
            error.UnexpectedNormal,
            error.WrongProtocol,
            => return error.NonRecoverable,
            error.RecvTimeout,
            error.Wkc,
            error.StateChangeTimeout,
            error.InvalidMbxConfiguration,
            error.Emergency,
            error.MbxOutFull,
            error.InvalidMbxContent,
            error.MbxTimeout,
            error.NoTransactionAvailable, // WTF is this?
            => continue :bus_scan,
            error.TransactionContention => unreachable,
        };
        std.log.info("Look mom! I got to OP!", .{});

        var print_timer = std.time.Timer.start() catch @panic("Timer unsupported");
        var cycle_count: u32 = 0;
        var recv_timeouts: u32 = 0;
        while (true) {

            // exchange process data
            if (md.sendRecvCyclicFrames()) {
                recv_timeouts = 0;
            } else |err| switch (err) {
                error.RecvTimeout => {
                    std.log.info("recv timeout!", .{});
                    recv_timeouts += 1;
                    if (recv_timeouts > args.max_recv_timeouts_before_rescan) continue :bus_scan;
                },
                error.LinkError,
                error.CurruptedFrame,
                => return error.NonRecoverable,
                error.NoTransactionAvailable,
                => unreachable,
                error.NotAllSubdevicesInOP,
                error.TopologyChanged,
                error.Wkc,
                => continue :bus_scan,
            }

            // do application
            cycle_count += 1;

            if (print_timer.read() > std.time.ns_per_s * 1) {
                print_timer.reset();
                std.log.info("frames/s: {}", .{cycle_count});
                cycle_count = 0;
            }
            gcat.sleepUntilNextCycle(md.first_cycle_time.?, args.cycle_time_us);
        }
    }
}
