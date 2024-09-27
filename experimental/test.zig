//! Run this file using: zig test path_to_this_file.zig
//!
//! We expect the first test to succeed and the second test to produce the const cast compile error.

const std = @import("std");
// All function parameters are constant in zig.

/// add one to the number I pass into this function by reference.
/// The reference (location in memory) is constant. But the contents of the memory
/// at that location can change.
pub fn addOneInPlace(num: *u8) void {
    num.* += 1;
}

/// The number I am passing into this function is constant and a new number is returned.
pub fn addOne(num: u8) u8 {
    return num + 1;
}

/// The location in memory is constant and the contents of the memory is constant.
pub fn addOneUsingReference(num: *const u8) u8 {
    return num.* + 1;
}

test "add one correctly" {
    var modifiable_number: u8 = 1;
    addOneInPlace(&modifiable_number);
    try std.testing.expect(modifiable_number == 2);

    const constant_number: u8 = 1;
    const new_constant_number: u8 = addOne(constant_number);
    try std.testing.expect(new_constant_number == 2);

    const new_constant_number_again = addOneUsingReference(&constant_number);
    try std.testing.expect(new_constant_number_again == 2);
}

test "add one illegally" {
    const constant_number: u8 = 1;
    addOneInPlace(&constant_number); // compile error here!
    try std.testing.expect(constant_number == 1);
}
