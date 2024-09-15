const std = @import("std");

pub const RealAndFakeError = error{
    RealError,
    FakeError,
};

pub fn foo() RealAndFakeError!void {
    return error.RealError;
}

test {
    try std.testing.expectError(error.RealError, foo());
}
