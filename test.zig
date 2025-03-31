const std = @import("std");

test {
    const allocator = std.testing.allocator;

    var map = std.StringArrayHashMap(void).init(allocator);
    defer map.deinit();

    const key2: [:0]const u8 = "s/3/outputs/pdo/0/entry/6/EL7031-0030_ENC_RxPDO-Map_Control_compact_Set_counter_value";
    try map.put(key2, void{});

    const key1: [:0]const u8 = "s/3/outputs/pdo/0/entry/2/EL7031-0030_ENC_RxPDO-Map_Control_compact_Set_counter";
    try map.put(key1, void{});
    map.get(key2) orelse return error.NotFound;
    map.get(key1) orelse return error.NotFound;
}
