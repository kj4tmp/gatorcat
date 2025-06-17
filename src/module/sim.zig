//! Deterministic Simulator for EtherCAT Networks

const std = @import("std");
const assert = std.debug.assert;

const ENI = @import("ENI.zig");
const nic = @import("nic.zig");
const telegram = @import("telegram.zig");

/// Provides a link layer that will simulate an ethercat network
/// specified using an ethercat network information struct.
///
/// Simulator advances one tick during recv() and returns frames
/// like a raw socket.
/// Simulator injests frames from application using send().
pub const Simulator = struct {
    eni: ENI,
    arena: *std.heap.ArenaAllocator,
    /// Frames waiting to be processed during tick().
    /// Appended by send().
    in_frames: *std.ArrayList(Frame),
    /// frames waiting to be returned by recv().
    /// Appended by tick().
    out_frames: *std.ArrayList(Frame),
    /// simulated subdevices
    subdevices: []Subdevice,

    const Frame = std.BoundedArray(u8, telegram.max_frame_length);

    pub const Options = struct {
        max_simultaneous_frames_in_flight: usize = 256,
    };

    /// Allocates once. Never allocates again.
    /// Call deinit to free resources.
    pub fn init(eni: ENI, allocator: std.mem.Allocator, options: Options) !Simulator {
        const arena = try allocator.create(std.heap.ArenaAllocator);
        errdefer allocator.destroy(arena);
        arena.* = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();

        const in_frames_slice = try arena.allocator().alloc(Frame, options.max_simultaneous_frames_in_flight);
        const in_frames = try arena.allocator().create(std.ArrayList(Frame));
        in_frames.* = std.ArrayList(Frame).fromOwnedSlice(std.testing.failing_allocator, in_frames_slice);
        in_frames.shrinkRetainingCapacity(0);

        const out_frames_slice = try arena.allocator().alloc(Frame, options.max_simultaneous_frames_in_flight);
        const out_frames = try arena.allocator().create(std.ArrayList(Frame));
        out_frames.* = std.ArrayList(Frame).fromOwnedSlice(std.testing.failing_allocator, out_frames_slice);
        out_frames.shrinkRetainingCapacity(0);

        const subdevices = try arena.allocator().alloc(Subdevice, eni.subdevices.len);
        for (subdevices, eni.subdevices) |*subdevice, config| {
            subdevice.* = Subdevice.init(config);
        }

        return Simulator{
            .eni = eni,
            .arena = arena,
            .in_frames = in_frames,
            .out_frames = out_frames,
            .subdevices = subdevices,
        };
    }
    pub fn deinit(self: *Simulator, allocator: std.mem.Allocator) void {
        self.arena.deinit();
        allocator.destroy(self.arena);
    }

    // add a frame to the processing queue
    pub fn send(ctx: *anyopaque, bytes: []const u8) std.posix.SendError!void {
        const self: *Simulator = @ptrCast(@alignCast(ctx));
        const frame = Frame.fromSlice(bytes) catch return error.MessageTooBig;
        self.in_frames.append(frame) catch return error.SystemResources;
    }

    // execute one tick in the simulator, return a frame if available
    pub fn recv(ctx: *anyopaque, out: []u8) std.posix.RecvFromError!usize {
        const self: *Simulator = @ptrCast(@alignCast(ctx));
        self.tick();
        // TODO: re-order frames randomly
        var out_stream = std.io.fixedBufferStream(out);
        if (self.out_frames.pop()) |frame| {
            return out_stream.write(frame.slice()) catch |err| switch (err) {
                error.NoSpaceLeft => return 0,
            };
        } else return 0;
        unreachable;
    }

    pub fn linkLayer(self: *Simulator) nic.LinkLayer {
        return nic.LinkLayer{
            .ptr = self,
            .vtable = &.{ .send = send, .recv = recv },
        };
    }

    pub fn tick(self: *Simulator) void {
        while (self.in_frames.pop()) |frame| {
            var mut_frame = frame;
            for (self.subdevices) |*subdevice| {
                subdevice.processFrame(&mut_frame);
            }
            self.out_frames.appendAssumeCapacity(mut_frame);
        }
    }
};

pub const Subdevice = struct {
    config: ENI.SubdeviceConfiguration,
    physical_memory: [4096]u8,
    pub fn init(config: ENI.SubdeviceConfiguration) Subdevice {
        return Subdevice{
            .config = config,
            .physical_memory = @splat(0),
        };
    }

    pub fn processFrame(self: *Subdevice, frame: *Simulator.Frame) void {
        var scratch_datagrams: [15]telegram.Datagram = undefined;
        const ethernet_frame = telegram.EthernetFrame.deserialize(frame.slice(), &scratch_datagrams) catch return;
        const datagrams = ethernet_frame.ethercat_frame.datagrams;
        skip_datagram: for (datagrams) |*datagram| {
            // TODO: operate if address zero
            // increment address field
            switch (datagram.header.command) {
                .NOP => {}, // no operation
                .BRD => {
                    if (!validOffsetLen(
                        datagram.header.address.position.offset,
                        datagram.header.length,
                    )) {
                        continue :skip_datagram;
                    }
                    assert(datagram.data.len == datagram.header.length);
                    const start_addr = @as(usize, datagram.header.address.position.offset);
                    const end_exclusive: usize = start_addr + datagram.header.length;

                    const read_region = self.physical_memory[start_addr..end_exclusive];
                    for (datagram.data, read_region) |*dest, source| {
                        dest.* |= source;
                    }
                    datagram.wkc +%= 1;
                    // subdevice shall increment the address
                    // Ref: IEC 61158-3-12:2019 5.2.4
                    datagram.header.address.position.autoinc_address +%= 1;
                },
                .BWR => {
                    if (!validOffsetLen(
                        datagram.header.address.position.offset,
                        datagram.header.length,
                    )) {
                        continue :skip_datagram;
                    }
                    assert(datagram.data.len == datagram.header.length);
                    const start_addr = @as(usize, datagram.header.address.position.offset);
                    const end_exclusive: usize = start_addr + datagram.header.length;

                    const write_region = self.physical_memory[start_addr..end_exclusive];
                    for (datagram.data, write_region) |source, *dest| {
                        dest.* = source;
                    }
                    datagram.wkc +%= 1;
                },

                else => {}, // TODO
            }
        }
        var new_frame = Simulator.Frame{};
        new_frame.len = frame.len;
        var new_eth_frame = telegram.EthernetFrame.init(ethernet_frame.header, telegram.EtherCATFrame.init(datagrams));
        const num_written = new_eth_frame.serialize(null, new_frame.slice()) catch unreachable;
        assert(num_written == frame.len);
        frame.* = new_frame;
    }

    pub fn validOffsetLen(offset: u16, len: u11) bool {
        const end: u16, const overflowed = @addWithOverflow(offset, len);
        return (overflowed == 0 and end <= 4095);
    }
};

test {
    std.testing.refAllDecls(@This());
}
