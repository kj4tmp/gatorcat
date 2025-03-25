//! Run subcommand of the GatorCAT CLI.
//!
//! Intended to exemplify a reasonable default way of doing things with as little configuratiuon as possible.

const std = @import("std");
const assert = std.debug.assert;
const builtin = @import("builtin");

const gcat = @import("gatorcat");
const zbor = @import("zbor");
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
    zenoh: bool = false,
    pub const descriptions = .{
        .ifname = "Network interface to use for the bus scan.",
        .recv_timeout_us = "Frame receive timeout in microseconds.",
        .eeprom_timeout_us = "SII EEPROM timeout in microseconds.",
        .INIT_timeout_us = "state transition to INIT timeout in microseconds.",
        .zenoh = "enable zenoh",
    };
};

pub const RunError = error{
    /// Reached a non-recoverable state and the program should die.
    NonRecoverable,
};

pub fn run(allocator: std.mem.Allocator, args: Args) RunError!void {
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

        var maybe_zh = if (args.zenoh) ZenohHandler.init(
            allocator,
            eni.value,
        ) catch return error.NonRecoverable else null;
        defer {
            if (maybe_zh) |_| {
                maybe_zh.?.deinit();
            }
        }

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

            if (maybe_zh) |*zh| {
                zh.publishInputs(&md, eni.value) catch break :bus_scan; // TODO: correct action here?
            }

            // do application
            cycle_count += 1;

            if (print_timer.read() > std.time.ns_per_s * 1) {
                print_timer.reset();
                std.log.info("cycles/s: {}", .{cycle_count});
                cycle_count = 0;
            }
            gcat.sleepUntilNextCycle(md.first_cycle_time.?, args.cycle_time_us);
        }
    }
}

pub const ZenohHandler = struct {
    arena: *std.heap.ArenaAllocator,
    config: *zenoh.c.z_owned_config_t,
    session: *zenoh.c.z_owned_session_t,
    // TODO: store string keys as [:0] const u8 by calling hash map ourselves with StringContext
    pubs: std.StringArrayHashMap(zenoh.c.z_owned_publisher_t),

    pub fn init(parent_allocator: std.mem.Allocator, eni: gcat.ENI) !ZenohHandler {
        var arena = try parent_allocator.create(std.heap.ArenaAllocator);
        arena.* = .init(parent_allocator);
        errdefer parent_allocator.destroy(arena);
        errdefer arena.deinit();
        const allocator = arena.allocator();

        std.log.err("here", .{});
        const config = try allocator.create(zenoh.c.z_owned_config_t);
        std.log.err("ptr: {x}", .{@intFromPtr(config)});
        try zenoh.err(zenoh.c.z_config_default(config));
        errdefer zenoh.drop(zenoh.move(config));

        var open_options: zenoh.c.z_open_options_t = undefined;
        zenoh.c.z_open_options_default(&open_options);

        const session = try allocator.create(zenoh.c.z_owned_session_t);
        const open_result = zenoh.c.z_open(session, zenoh.move(config), &open_options);
        try zenoh.err(open_result);
        errdefer zenoh.drop(zenoh.move(session));

        var pubs = std.StringArrayHashMap(zenoh.c.z_owned_publisher_t).init(allocator);
        errdefer pubs.deinit();
        errdefer {
            for (pubs.values()) |*publisher| {
                zenoh.drop(zenoh.move(publisher));
            }
        }

        for (eni.subdevices) |subdevice| {
            for (subdevice.inputs) |input| {
                for (input.entries) |entry| {
                    if (entry.pv_name == null) continue;
                    var publisher: zenoh.c.z_owned_publisher_t = undefined;
                    var view_keyexpr: zenoh.c.z_view_keyexpr_t = undefined;
                    std.log.info("declaring publisher: {s}, type: {}", .{ entry.pv_name.?, entry.type });
                    const result = zenoh.c.z_view_keyexpr_from_str(&view_keyexpr, entry.pv_name.?.ptr);
                    try zenoh.err(result);
                    var publisher_options: zenoh.c.z_publisher_options_t = undefined;
                    zenoh.c.z_publisher_options_default(&publisher_options);
                    publisher_options.congestion_control = zenoh.c.Z_CONGESTION_CONTROL_DROP;
                    const result2 = zenoh.c.z_declare_publisher(zenoh.loan(session), &publisher, zenoh.loan(&view_keyexpr), &publisher_options);
                    try zenoh.err(result2);
                    const put_result = try pubs.getOrPutValue(entry.pv_name.?, publisher);
                    if (put_result.found_existing) return error.PVNameConflict; // TODO: assert this?
                }
            }
        }
        return ZenohHandler{
            .arena = arena,
            .config = config,
            .session = session,
            .pubs = pubs,
        };
    }

    /// Asserts the given key exists.
    pub fn publishAssumeKey(self: *ZenohHandler, key: [:0]const u8, payload: []const u8) !void {
        var options: zenoh.c.z_publisher_put_options_t = undefined;
        zenoh.c.z_publisher_put_options_default(&options);
        var bytes: zenoh.c.z_owned_bytes_t = undefined;
        const result_copy = zenoh.c.z_bytes_copy_from_buf(&bytes, payload.ptr, payload.len);
        try zenoh.err(result_copy);
        errdefer zenoh.drop(zenoh.move(&bytes));
        var publisher = self.pubs.get(key).?;
        const result = zenoh.c.z_publisher_put(zenoh.loan(&publisher), zenoh.move(&bytes), &options);
        try zenoh.err(result);
        errdefer comptime unreachable;
    }

    pub fn deinit(self: *ZenohHandler) void {
        for (self.pubs.values()) |*publisher| {
            zenoh.drop(zenoh.move(publisher));
        }
        zenoh.drop(zenoh.move(self.config));
        zenoh.drop(zenoh.move(self.session));
        self.arena.deinit();
    }

    // returns number of put calls
    pub fn publishInputs(self: *ZenohHandler, md: *const gcat.MainDevice, eni: gcat.ENI) !void {
        for (md.subdevices, eni.subdevices) |sub, sub_config| {
            const data = sub.getInputProcessData();
            var fbs = std.io.fixedBufferStream(data);
            const reader = fbs.reader();
            var bit_reader = gcat.wire.lossyBitReader(reader);

            for (sub_config.inputs) |input| {
                for (input.entries) |entry| {
                    const key = entry.pv_name orelse {
                        bit_reader.readBitsNoEof(void, entry.bits) catch unreachable;
                        continue;
                    };
                    var out_buffer: [32]u8 = undefined; // TODO: this is arbitrary
                    var fbs_out = std.io.fixedBufferStream(&out_buffer);
                    const writer = fbs_out.writer();
                    switch (entry.type) {
                        .BOOLEAN => {
                            const value = bit_reader.readBitsNoEof(bool, entry.bits) catch unreachable;
                            switch (value) {
                                false => {
                                    try self.publishAssumeKey(key, &.{0xf4});
                                    continue;
                                },
                                true => {
                                    try self.publishAssumeKey(key, &.{0xf5});
                                    continue;
                                },
                            }
                        },
                        .BIT1 => {
                            const value = bit_reader.readBitsNoEof(u1, entry.bits) catch unreachable;
                            zbor.stringify(value, .{}, writer) catch unreachable;
                        },
                        .BIT2 => {
                            const value = bit_reader.readBitsNoEof(u2, entry.bits) catch unreachable;
                            zbor.stringify(value, .{}, writer) catch unreachable;
                        },
                        .BIT3 => {
                            const value = bit_reader.readBitsNoEof(u3, entry.bits) catch unreachable;
                            zbor.stringify(value, .{}, writer) catch unreachable;
                        },
                        .BIT4 => {
                            const value = bit_reader.readBitsNoEof(u4, entry.bits) catch unreachable;
                            zbor.stringify(value, .{}, writer) catch unreachable;
                        },
                        .BIT5 => {
                            const value = bit_reader.readBitsNoEof(u5, entry.bits) catch unreachable;
                            zbor.stringify(value, .{}, writer) catch unreachable;
                        },
                        .BIT6 => {
                            const value = bit_reader.readBitsNoEof(u6, entry.bits) catch unreachable;
                            zbor.stringify(value, .{}, writer) catch unreachable;
                        },
                        .BIT7 => {
                            const value = bit_reader.readBitsNoEof(u7, entry.bits) catch unreachable;
                            zbor.stringify(value, .{}, writer) catch unreachable;
                        },
                        // TODO: encode as bit array?
                        .BIT8, .UNSIGNED8, .BYTE, .BITARR8 => {
                            const value = bit_reader.readBitsNoEof(u8, entry.bits) catch unreachable;
                            zbor.stringify(value, .{}, writer) catch unreachable;
                        },
                        .INTEGER8 => {
                            const value = bit_reader.readBitsNoEof(i8, entry.bits) catch unreachable;
                            zbor.stringify(value, .{}, writer) catch unreachable;
                        },
                        .INTEGER16 => {
                            const value = bit_reader.readBitsNoEof(i16, entry.bits) catch unreachable;
                            zbor.stringify(value, .{}, writer) catch unreachable;
                        },
                        .INTEGER32 => {
                            const value = bit_reader.readBitsNoEof(i32, entry.bits) catch unreachable;
                            zbor.stringify(value, .{}, writer) catch unreachable;
                        },
                        // TODO: encode as bit array?
                        .UNSIGNED16, .BITARR16 => {
                            const value = bit_reader.readBitsNoEof(u16, entry.bits) catch unreachable;
                            zbor.stringify(value, .{}, writer) catch unreachable;
                        },
                        .UNSIGNED24 => {
                            const value = bit_reader.readBitsNoEof(u24, entry.bits) catch unreachable;
                            zbor.stringify(value, .{}, writer) catch unreachable;
                        },
                        // TODO: encode as bit array?
                        .UNSIGNED32, .BITARR32 => {
                            const value = bit_reader.readBitsNoEof(u32, entry.bits) catch unreachable;
                            zbor.stringify(value, .{}, writer) catch unreachable;
                        },
                        .UNSIGNED40 => {
                            const value = bit_reader.readBitsNoEof(u40, entry.bits) catch unreachable;
                            zbor.stringify(value, .{}, writer) catch unreachable;
                        },
                        .UNSIGNED48 => {
                            const value = bit_reader.readBitsNoEof(u48, entry.bits) catch unreachable;
                            zbor.stringify(value, .{}, writer) catch unreachable;
                        },
                        .UNSIGNED56 => {
                            const value = bit_reader.readBitsNoEof(u56, entry.bits) catch unreachable;
                            zbor.stringify(value, .{}, writer) catch unreachable;
                        },
                        .UNSIGNED64 => {
                            const value = bit_reader.readBitsNoEof(u64, entry.bits) catch unreachable;
                            zbor.stringify(value, .{}, writer) catch unreachable;
                        },
                        .REAL32 => {
                            const value = bit_reader.readBitsNoEof(f32, entry.bits) catch unreachable;
                            zbor.stringify(value, .{}, writer) catch unreachable;
                        },
                        .INTEGER24 => {
                            const value = bit_reader.readBitsNoEof(i24, entry.bits) catch unreachable;
                            zbor.stringify(value, .{}, writer) catch unreachable;
                        },
                        .INTEGER40 => {
                            const value = bit_reader.readBitsNoEof(i40, entry.bits) catch unreachable;
                            zbor.stringify(value, .{}, writer) catch unreachable;
                        },
                        .INTEGER48 => {
                            const value = bit_reader.readBitsNoEof(i48, entry.bits) catch unreachable;
                            zbor.stringify(value, .{}, writer) catch unreachable;
                        },
                        .INTEGER56 => {
                            const value = bit_reader.readBitsNoEof(i56, entry.bits) catch unreachable;
                            zbor.stringify(value, .{}, writer) catch unreachable;
                        },
                        .INTEGER64 => {
                            const value = bit_reader.readBitsNoEof(i64, entry.bits) catch unreachable;
                            zbor.stringify(value, .{}, writer) catch unreachable;
                        },
                        else => {
                            bit_reader.readBitsNoEof(void, entry.bits) catch unreachable;
                            continue;
                        },
                    }
                    try self.publishAssumeKey(key, fbs_out.getWritten());
                }
            }
        }
    }
};
