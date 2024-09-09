const std = @import("std");

pub const MySliceHolder = struct {
    slice: []const u8,
    pub fn makeMySlice() MySliceHolder {
        return MySliceHolder{
            .slice = &.{ 0, 1, 2, 3 },
        };
    }
};

test {
    const expected = [_]u8{ 0, 1, 2, 3 };
    try std.testing.expectEqualSlices(
        u8,
        &expected,
        MySliceHolder.makeMySlice().slice,
    );
}
