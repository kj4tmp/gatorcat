//! Deterministic Simulator for EtherCAT Networks

const std = @import("std");
const assert = std.debug.assert;

const ENI = @import("ENI.zig");
const nic = @import("nic.zig");
const telegram = @import("telegram.zig");

pub const Simulator = struct {
    eni: ENI,
    arena: *std.heap.ArenaAllocator,
    frames: *std.ArrayList(Frame),

    const Frame = std.BoundedArray(u8, telegram.max_frame_length);

    pub const Options = struct {
        max_simultaneous_frames_in_flight: usize = 256,
    };

    pub fn init(eni: ENI, allocator: std.mem.Allocator, options: Options) !Simulator {
        const arena = try allocator.create(std.heap.ArenaAllocator);
        errdefer allocator.destroy(arena);
        arena.* = std.heap.ArenaAllocator.init(allocator);

        const frames_slice = try arena.allocator().alloc(Frame, options.max_simultaneous_frames_in_flight);
        errdefer arena.allocator().free(frames_slice);

        const frames = try arena.allocator().create(std.ArrayList(Frame));
        errdefer arena.allocator().destroy(frames);

        frames.* = std.ArrayList(Frame).fromOwnedSlice(std.testing.failing_allocator, frames_slice);
        frames.shrinkRetainingCapacity(0);

        return Simulator{
            .eni = eni,
            .arena = arena,
            .frames = frames,
        };
    }
    pub fn deinit(self: *Simulator, allocator: std.mem.Allocator) void {
        self.arena.deinit();
        allocator.destroy(self.arena);
    }
    pub fn tick(self: *Simulator) void {
        _ = self;
    }

    // add a frame to the processing queue
    pub fn send(ctx: *anyopaque, bytes: []const u8) std.posix.SendError!void {
        const self: *Simulator = @ptrCast(@alignCast(ctx));
        const frame = Frame.fromSlice(bytes) catch return error.MessageTooBig;
        self.frames.append(frame) catch return error.SystemResources;
    }

    // execute one tick in the simulator, return a frame if available
    pub fn recv(ctx: *anyopaque, out: []u8) std.posix.RecvFromError!usize {
        const self: *Simulator = @ptrCast(@alignCast(ctx));
        self.tick();
        var out_stream = std.io.fixedBufferStream(out);
        if (self.frames.popOrNull()) |frame| {
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
};

test {
    std.testing.refAllDecls(@This());
}
