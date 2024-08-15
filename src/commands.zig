const std = @import("std");
const nic = @import("nic.zig");
const zerosFromPack = nic.zerosFromPack;
const eCatFromPack = nic.eCatFromPack;
const packFromECat = nic.packFromECat;
const telegram = @import("telegram.zig");
const assert = std.debug.assert;
fn sendDatagram(
    port: *nic.Port,
    command: telegram.Command,
    address: u32,
    data: []u8,
    timeout_us: u32,
) !u16 {
    var datagrams: [1]telegram.Datagram = .{
        telegram.Datagram{
            .header = telegram.DatagramHeader{
                .command = command,
                .idx = 0,
                .address = address,
                .length = 0,
                .circulating = false,
                .next = false,
                .irq = 0,
            },
            .data = data,
            .wkc = 0,
        },
    };
    try port.send_recv_datagrams(
        &datagrams,
        timeout_us,
    );
    return datagrams[0].wkc;
}

/// No operation.
/// The subdevice ignores the command.
pub fn NOP(port: *nic.Port) void {
    _ = port;
}
/// Auto increment physical read.
/// A subdevice increments the address.
/// A subdevice writes the data it has read to the EtherCAT datagram
/// if the address received is zero.
pub fn APRD(
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

/// Auto-increment physical read a packed struct
pub fn APRD_ps(
    port: *nic.Port,
    comptime packed_struct_type: type,
    address: telegram.PositionAddress,
    timeout_us: u32,
) !struct { ps: packed_struct_type, wkc: u16 } {
    var data = zerosFromPack(packed_struct_type);
    const wkc = try APRD(port, address, &data, timeout_us);
    return .{ .ps = packFromECat(packed_struct_type, data), .wkc = wkc };
}

/// Auto increment physical write.
/// A subdevice increments the address.
/// A subdevice writes data to a memory area if the address received is zero.
pub fn APWR(
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

/// Auto-increment physical write a packed struct
pub fn APWR_ps(
    port: *nic.Port,
    packed_struct: anytype,
    address: telegram.PositionAddress,
    timeout_us: u32,
) !u16 {
    var data = eCatFromPack(packed_struct);
    const wkc = try APWR(port, address, &data, timeout_us);
    return wkc;
}

/// Auto increment physical read write.
/// A subdevice increments the address.
/// A subdevice writes the data it has read to the EtherCAT datagram and writes
/// the newly acquired data to the same memory area if the received address is zero.
pub fn APRW(
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

/// Auto-increment physical read-write a packed struct
pub fn APRW_ps(
    port: *nic.Port,
    packed_struct: anytype,
    address: telegram.PositionAddress,
    timeout_us: u32,
) !struct { ps: @TypeOf(packed_struct), wkc: u16 } {
    var data = eCatFromPack(packed_struct);
    const wkc = try APRW(port, address, &data, timeout_us);
    return .{ .ps = packFromECat(@TypeOf(packed_struct), data), .wkc = wkc };
}

/// Configured address physical read.
/// A subdevice writes the data it has read to the EtherCAT datagram if its subdevice
/// address matches one of the addresses configured in the datagram.
pub fn FPRD(
    port: *nic.Port,
    address: telegram.StationAddress,
    data: []u8,
    timeout_us: u32,
) !u16 {
    sendDatagram(
        port,
        telegram.Command.FPRD,
        @bitCast(address),
        data,
        timeout_us,
    );
}

/// Configured address physical read a packed struct
pub fn FPRD_ps(
    port: *nic.Port,
    comptime packed_struct_type: type,
    address: telegram.StationAddress,
    timeout_us: u32,
) !struct { ps: packed_struct_type, wkc: u16 } {
    var data = zerosFromPack(packed_struct_type);
    const wkc = try FPRD(port, address, &data, timeout_us);
    return .{ .ps = packFromECat(packed_struct_type, data), .wkc = wkc };
}

/// Configured address physical write.
/// A subdevice writes data to a memory area if its subdevice address matches one
/// of the addresses configured in the datagram.
pub fn FPWR(
    port: *nic.Port,
    address: telegram.StationAddress,
    data: []const u8,
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

/// Configured address physical write a packed struct
pub fn FPWR_ps(
    port: *nic.Port,
    packed_struct: anytype,
    address: telegram.StationAddress,
    timeout_us: u32,
) !u16 {
    var data = eCatFromPack(packed_struct);
    const wkc = try FPWR(port, address, &data, timeout_us);
    return wkc;
}

/// Configured address physical read write.
/// A subdevice writes the data it has read to the EtherCAT datagram and writes
/// the newly acquired data to the same memory area if its subdevice address matches
/// one of the addresses configured in the datagram.
pub fn FPRW(
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

/// Configured address physical read-write a packed struct
pub fn FPRW_ps(
    port: *nic.Port,
    packed_struct: anytype,
    address: telegram.StationAddress,
    timeout_us: u32,
) !struct { ps: @TypeOf(packed_struct), wkc: u16 } {
    var data = eCatFromPack(packed_struct);
    const wkc = try FPRW(port, address, &data, timeout_us);
    return .{ .ps = packFromECat(@TypeOf(packed_struct), data), .wkc = wkc };
}

/// Broadcast read.
/// All subdevices write a logical OR of the data from the memory area and the data
/// from the EtherCAT datagram to the EtherCAT datagram. All subdevices increment the
/// position field.
pub fn BRD(
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

/// Broadcast read a packed struct
pub fn BRD_ps(
    port: *nic.Port,
    comptime packed_struct_type: type,
    address: telegram.PositionAddress,
    timeout_us: u32,
) !struct { ps: packed_struct_type, wkc: u16 } {
    var data = zerosFromPack(packed_struct_type);
    const wkc = try BRD(port, address, &data, timeout_us);
    return .{ .ps = packFromECat(packed_struct_type, data), .wkc = wkc };
}

/// Broadcast write.
/// All subdevices write data to a memory area. All subdevices increment the position field.
pub fn BWR(
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

/// Broadcast write a packed struct
pub fn BWR_ps(
    port: *nic.Port,
    packed_struct: anytype,
    address: telegram.PositionAddress,
    timeout_us: u32,
) !u16 {
    var data = eCatFromPack(packed_struct);
    const wkc = try BWR(port, address, &data, timeout_us);
    return wkc;
}

/// Broadcast read write.
/// All subdevices write a logical OR of the data from the memory area and the data from the
/// EtherCAT datagram to the EtherCAT datagram; all subdevices write data to the memory area.
/// BRW is typically not used. All subdevices increment the position field.
pub fn BRW(
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

/// Broadcast read-write a packed struct
pub fn BRW_ps(
    port: *nic.Port,
    packed_struct: anytype,
    address: telegram.PositionAddress,
    timeout_us: u32,
) !struct { ps: @TypeOf(packed_struct), wkc: u16 } {
    var data = eCatFromPack(packed_struct);
    const wkc = try BRW(port, address, &data, timeout_us);
    return .{ .ps = packFromECat(@TypeOf(packed_struct), data), .wkc = wkc };
}

/// Logical memory read.
/// A subdevice writes data it has read to the EtherCAT datagram if the address received
/// matches one of the FMMU areas configured for reading.
pub fn LRD(
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
/// Subdevices write data to their memory area if the address received matches one of
/// the FMMU areas configured for writing.
pub fn LWR(
    port: *nic.Port,
    address: telegram.LogicalAddress,
    data: []const u8,
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
/// matches one of the FMMU areas configured for reading. Subdevices write data to their memory area
/// if the address received matches one of the FMMU areas configured for writing.
pub fn LRW(
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
pub fn ARMW(
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
pub fn FRMW(
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
