const std = @import("std");
const assert = std.debug.assert;

const nic = @import("nic.zig");
const wire = @import("wire.zig");
const telegram = @import("telegram.zig");

fn sendDatagram(
    port: *nic.Port,
    command: telegram.Command,
    address: u32,
    data: []u8,
    timeout_us: u32,
) !u16 {
    assert(data.len <= telegram.Datagram.max_data_length);

    var datagrams: [1]telegram.Datagram = .{
        telegram.Datagram.init(
            command,
            address,
            false,
            data,
        ),
    };
    var frame = telegram.EtherCATFrame.init(&datagrams) catch |err| switch (err) {
        error.Overflow => unreachable,
        error.NoSpaceLeft => unreachable,
    };
    port.send_recv_frame(
        &frame,
        &frame,
        timeout_us,
    ) catch |err| switch (err) {
        // only one datagram so it should fit
        error.FrameSerializationFailure => unreachable,
        error.RecvTimeout => return error.RecvTimeout,
        error.LinkError => return error.LinkError,
        error.CurruptedFrame => return error.CurruptedFrame,
        error.TransactionContention => return error.TransactionContention,
    };
    // checked by telegram.EtherCATFrame.isCurrupted
    assert(data.len == frame.datagrams().slice()[0].data.len);
    @memcpy(data, frame.datagrams().slice()[0].data);
    return frame.datagrams().slice()[0].wkc;
}

/// No operation.
/// The subdevice ignores the command.
pub fn nop(port: *nic.Port, timeout_us: u32) !void {
    var data: [1]u8 = .{0};
    // wkc can be ignored on NOP, it is always zero
    _ = try sendDatagram(
        port,
        telegram.Command.NOP,
        0,
        &data,
        timeout_us,
    );
}

/// Auto increment physical read.
/// A subdevice increments the address.
/// A subdevice writes the data it has read to the EtherCAT datagram
/// if the address received is zero.
pub fn aprd(
    port: *nic.Port,
    address: telegram.PositionAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        port,
        telegram.Command.APRD,
        @bitCast(address),
        data,
        timeout_us,
    );
}

/// Auto-increment physical read a packable type
pub fn aprdPack(
    port: *nic.Port,
    comptime packed_type: type,
    address: telegram.PositionAddress,
    timeout_us: u32,
) !struct { ps: packed_type, wkc: u16 } {
    var data = wire.zerosFromPack(packed_type);
    const wkc = try aprd(port, address, &data, timeout_us);
    return .{ .ps = wire.packFromECat(packed_type, data), .wkc = wkc };
}

/// Auto increment physical write.
/// A subdevice increments the address.
/// A subdevice writes data to a memory area if the address received is zero.
pub fn apwr(
    port: *nic.Port,
    address: telegram.PositionAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        port,
        telegram.Command.APWR,
        @bitCast(address),
        data,
        timeout_us,
    );
}

pub fn apwrPackWkc(
    port: *nic.Port,
    packed_type: anytype,
    address: telegram.PositionAddress,
    timeout_us: u32,
    expected_wkc: u16,
) !void {
    var data = wire.eCatFromPack(packed_type);
    const wkc = try apwr(port, address, &data, timeout_us);
    if (wkc != expected_wkc) return error.Wkc;
}

/// Auto-increment physical write a packable type
pub fn apwrPack(
    port: *nic.Port,
    packed_type: anytype,
    address: telegram.PositionAddress,
    timeout_us: u32,
) !u16 {
    var data = wire.eCatFromPack(packed_type);
    const wkc = try apwr(port, address, &data, timeout_us);
    return wkc;
}

/// Auto increment physical read write.
/// A subdevice increments the address.
/// A subdevice writes the data it has read to the EtherCAT datagram and writes
/// the newly acquired data to the same memory area if the received address is zero.
pub fn aprw(
    port: *nic.Port,
    address: telegram.PositionAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        port,
        telegram.Command.APRW,
        @bitCast(address),
        data,
        timeout_us,
    );
}

/// Auto-increment physical read-write a packable type
pub fn aprwPack(
    port: *nic.Port,
    packed_type: anytype,
    address: telegram.PositionAddress,
    timeout_us: u32,
) !struct { ps: @TypeOf(packed_type), wkc: u16 } {
    var data = wire.eCatFromPack(packed_type);
    const wkc = try aprw(port, address, &data, timeout_us);
    return .{ .ps = wire.packFromECat(@TypeOf(packed_type), data), .wkc = wkc };
}

/// Configured address physical read.
/// A subdevice writes the data it has read to the EtherCAT datagram if its subdevice
/// address matches one of the addresses configured in the datagram.
pub fn fprd(
    port: *nic.Port,
    address: telegram.StationAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        port,
        telegram.Command.FPRD,
        @bitCast(address),
        data,
        timeout_us,
    );
}

pub fn fprdWkc(
    port: *nic.Port,
    address: telegram.StationAddress,
    data: []u8,
    timeout_us: u32,
    expected_wkc: u16,
) !void {
    const wkc = try fprd(port, address, data, timeout_us);
    if (wkc != expected_wkc) return error.Wkc;
}

/// Configured address physical read a packable type
pub fn fprdPack(
    port: *nic.Port,
    comptime packed_type: type,
    address: telegram.StationAddress,
    timeout_us: u32,
) !struct { ps: packed_type, wkc: u16 } {
    var data = wire.zerosFromPack(packed_type);
    const wkc = try fprd(port, address, &data, timeout_us);
    return .{ .ps = wire.packFromECat(packed_type, data), .wkc = wkc };
}

/// Configured address physical read a packable type, expect wkc
//
// TODO: refactor wkc handling?
pub fn fprdPackWkc(
    port: *nic.Port,
    comptime packed_type: type,
    address: telegram.StationAddress,
    timeout_us: u32,
    expected_wkc: u16,
) !packed_type {
    const res = try fprdPack(
        port,
        packed_type,
        address,
        timeout_us,
    );
    if (res.wkc != expected_wkc) {
        return error.Wkc;
    }
    return res.ps;
}

/// Configured address physical write.
/// A subdevice writes data to a memory area if its subdevice address matches one
/// of the addresses configured in the datagram.
pub fn fpwr(
    port: *nic.Port,
    address: telegram.StationAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        port,
        telegram.Command.FPWR,
        @bitCast(address),
        data,
        timeout_us,
    );
}

pub fn fpwrWkc(
    port: *nic.Port,
    address: telegram.StationAddress,
    data: []u8,
    timeout_us: u32,
    expected_wkc: u16,
) !void {
    const wkc = try fpwr(port, address, data, timeout_us);
    if (wkc != expected_wkc) return error.Wkc;
}

/// Configured address physical write a packable type
pub fn fpwrPack(
    port: *nic.Port,
    packed_type: anytype,
    address: telegram.StationAddress,
    timeout_us: u32,
) !u16 {
    var data = wire.eCatFromPack(packed_type);
    const wkc = try fpwr(port, address, &data, timeout_us);
    return wkc;
}

pub fn fpwrPackWkc(
    port: *nic.Port,
    packed_type: anytype,
    address: telegram.StationAddress,
    timeout_us: u32,
    expected_wkc: u16,
) !void {
    const wkc = try fpwrPack(port, packed_type, address, timeout_us);
    if (wkc != expected_wkc) return error.Wkc;
}

/// Configured address physical read write.
/// A subdevice writes the data it has read to the EtherCAT datagram and writes
/// the newly acquired data to the same memory area if its subdevice address matches
/// one of the addresses configured in the datagram.
pub fn fprw(
    port: *nic.Port,
    address: telegram.StationAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        port,
        telegram.Command.FPRW,
        @bitCast(address),
        data,
        timeout_us,
    );
}

/// Configured address physical read-write a packable type
pub fn fprwPack(
    port: *nic.Port,
    packed_type: anytype,
    address: telegram.StationAddress,
    timeout_us: u32,
) !struct { ps: @TypeOf(packed_type), wkc: u16 } {
    var data = wire.eCatFromPack(packed_type);
    const wkc = try fprw(port, address, &data, timeout_us);
    return .{ .ps = wire.packFromECat(@TypeOf(packed_type), data), .wkc = wkc };
}

/// Broadcast read.
/// All subdevices write a logical OR of the data from the memory area and the data
/// from the EtherCAT datagram to the EtherCAT datagram. All subdevices increment the
/// position field.
pub fn brd(
    port: *nic.Port,
    address: telegram.PositionAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        port,
        telegram.Command.BRD,
        @bitCast(address),
        data,
        timeout_us,
    );
}

/// Broadcast read a packable type
pub fn brdPack(
    port: *nic.Port,
    comptime packed_type: type,
    address: telegram.PositionAddress,
    timeout_us: u32,
) !struct { ps: packed_type, wkc: u16 } {
    var data = wire.zerosFromPack(packed_type);
    const wkc = try brd(port, address, &data, timeout_us);
    return .{ .ps = wire.packFromECat(packed_type, data), .wkc = wkc };
}

/// Broadcast write.
/// All subdevices write data to a memory area. All subdevices increment the position field.
pub fn bwr(
    port: *nic.Port,
    address: telegram.PositionAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        port,
        telegram.Command.BWR,
        @bitCast(address),
        data,
        timeout_us,
    );
}

pub fn bwrPackWkc(
    port: *nic.Port,
    packed_type: anytype,
    address: telegram.PositionAddress,
    timeout_us: u32,
    expected_wkc: u16,
) !void {
    var data = wire.eCatFromPack(packed_type);
    const wkc = try bwr(port, address, &data, timeout_us);
    if (wkc != expected_wkc) return error.Wkc;
}

/// Broadcast write a packable type
pub fn bwrPack(
    port: *nic.Port,
    packed_type: anytype,
    address: telegram.PositionAddress,
    timeout_us: u32,
) !u16 {
    var data = wire.eCatFromPack(packed_type);
    const wkc = try bwr(port, address, &data, timeout_us);
    return wkc;
}

/// Broadcast read write.
/// All subdevices write a logical OR of the data from the memory area and the data from the
/// EtherCAT datagram to the EtherCAT datagram; all subdevices write data to the memory area.
/// BRW is typically not used. All subdevices increment the position field.
pub fn brw(
    port: *nic.Port,
    address: telegram.PositionAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        port,
        telegram.Command.BRW,
        @bitCast(address),
        data,
        timeout_us,
    );
}

/// Broadcast read-write a packable type
pub fn brwPack(
    port: *nic.Port,
    packed_type: anytype,
    address: telegram.PositionAddress,
    timeout_us: u32,
) !struct { ps: @TypeOf(packed_type), wkc: u16 } {
    var data = wire.eCatFromPack(packed_type);
    const wkc = try brw(port, address, &data, timeout_us);
    return .{ .ps = wire.packFromECat(@TypeOf(packed_type), data), .wkc = wkc };
}

/// Logical memory read.
/// A subdevice writes data it has read to the EtherCAT datagram if the address received
/// matches one of the FMMU areas configured for reading.
pub fn lrd(
    port: *nic.Port,
    address: telegram.LogicalAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        port,
        telegram.Command.LRD,
        @bitCast(address),
        data,
        timeout_us,
    );
}

/// Logical memory write.
/// SubDevices write data to their memory area if the address received matches one of
/// the FMMU areas configured for writing.
pub fn lwr(
    port: *nic.Port,
    address: telegram.LogicalAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        port,
        telegram.Command.LWR,
        @bitCast(address),
        data,
        timeout_us,
    );
}

/// Logical memory read write.
/// A subdevice writes data it has read to the EtherCAT datagram if the address received
/// matches one of the FMMU areas configured for reading. SubDevices write data to their memory area
/// if the address received matches one of the FMMU areas configured for writing.
pub fn lrw(
    port: *nic.Port,
    address: telegram.LogicalAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        port,
        telegram.Command.LRW,
        @bitCast(address),
        data,
        timeout_us,
    );
}

/// Auto increment physical read multiple write.
/// A subdevice increments the address field. A subdevice writes data it has read to the EtherCAT
/// datagram when the address received is zero, otherwise it writes data to the memory area.
pub fn armw(
    port: *nic.Port,
    address: telegram.PositionAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        port,
        telegram.Command.ARMW,
        @bitCast(address),
        data,
        timeout_us,
    );
}

/// Configured address physical read multiple write.
pub fn frmw(
    port: *nic.Port,
    address: telegram.StationAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    return sendDatagram(
        port,
        telegram.Command.FRMW,
        @bitCast(address),
        data,
        timeout_us,
    );
}

test {
    std.testing.refAllDecls(@This());
}
