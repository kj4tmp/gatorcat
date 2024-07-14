const std = @import("std");
const Timer = std.time.Timer;
const nic = @import("nic.zig");
const telegram = @import("telegram.zig");

/// No operation.
/// The subdevice ignores the command.
pub fn NOP(port: *nic.Port) void {
    _ = port;
}
/// Auto increment physical read.
/// A subdevice increments the address.
/// A subdevice writes the data it has read to the EtherCAT datagram
/// if the address received is zero.
pub fn APRD(port: *nic.Port) void {
    _ = port;
}
/// Auto increment physical write.
/// A subdevice increments the address.
/// A subdevice writes data to a memory area if the address received is zero.
pub fn APWR(port: *nic.Port) void {
    _ = port;
}
/// Auto increment physical read write.
/// A subdevice increments the address.
/// A subdevice writes the data it has read to the EtherCAT datagram and writes
/// the newly acquired data to the same memory area if the received address is zero.
pub fn APRW(port: *nic.Port) void {
    _ = port;
}
/// Configured address physical read.
/// A subdevice writes the data it has read to the EtherCAT datagram if its subdevice
/// address matches one of the addresses configured in the datagram.
pub fn FPRD(port: *nic.Port) void {
    _ = port;
}
/// Configured address physical write.
/// A subdevice writes data to a memory area if its subdevice address matches one
/// of the addresses configured in the datagram.
pub fn FPWR(port: *nic.Port) void {
    _ = port;
}
/// Configured address physical read write.
/// A subdevice writes the data it has read to the EtherCAT datagram and writes
/// the newly acquired data to the same memory area if its subdevice address matches
/// one of the addresses configured in the datagram.
pub fn FPRW(port: *nic.Port) void {
    _ = port;
}
/// Broadcast read.
/// All subdevices write a logical OR of the data from the memory area and the data
/// from the EtherCAT datagram to the EtherCAT datagram. All subdevices increment the
/// position field.
pub fn BRD(port: *nic.Port, address: telegram.PositionAddress, data: []u8, timeout_us: u32) !u16 {
    const datagram_header = telegram.DatagramHeader{
        .command = telegram.Command.BRD,
        .idx = 0,
        .address = telegram.Address{
            .position_address = address,
        },
        .length = 0,
        .circulating = false,
        .next = false,
        .irq = 0,
    };
    var datagram = telegram.Datagram{
        .header = datagram_header,
        .data = data,
        .wkc = 0,
    };
    const ecat_header = telegram.EtherCATHeader{
        .length = 0,
    };
    const ecat_frame = telegram.EtherCATFrame{
        .header = ecat_header,
        .datagrams = @as(*[1]telegram.Datagram, &datagram),
    };
    const padding = std.mem.zeroes([46]u8);
    var frame = telegram.EthernetFrame{
        .header = nic.Port.get_ethernet_header(),
        .ethercat_frame = ecat_frame,
        .padding = undefined,
    };
    frame.padding = padding[0..frame.getRequiredPaddingLength()];

    var timer = try Timer.start();
    var idx: u8 = undefined;
    while (timer.read() < timeout_us * 1000) {
        idx = port.send_frame(frame) catch |err| switch (err) {
            error.NoFrameBufferAvailable => continue,
            else => unreachable,
        };
        break;
    } else {
        return error.Timeout;
    }
    defer port.release_frame_buffer(idx);
    var recv_frame: telegram.EthernetFrame = undefined;
    while (timer.read() < timeout_us * 1000) {
        recv_frame = port.fetch_frame(idx) catch |err| switch (err) {
            .FrameNotFound => continue,
        };
        break;
    } else {
        return error.Timeout;
    }
    return recv_frame.ethercat_frame.datagrams[0].wkc;
}
/// Broadcast write.
/// All subdevices write data to a memory area. All subdevices increment the position field.
pub fn BWR(port: *nic.Port) void {
    _ = port;
}
/// Broadcast read write.
/// All subdevices write a logical OR of the data from the memory area and the data from the
/// EtherCAT datagram to the EtherCAT datagram; all subdevices write data to the memory area.
/// BRW is typically not used. All subdevices increment the position field.
pub fn BRW(port: *nic.Port) void {
    _ = port;
}
/// Logical memory read.
/// A subdevice writes data it has read to the EtherCAT datagram if the address received
/// matches one of the FMMU areas configured for reading.
pub fn LRD(port: *nic.Port) void {
    _ = port;
}
/// Logical memory write.
/// Subdevices write data to their memory area if the address received matches one of
/// the FMMU areas configured for writing.
pub fn LWR(port: *nic.Port) void {
    _ = port;
}
/// Logical memory read write.
/// A subdevice writes data it has read to the EtherCAT datagram if the address received
/// matches one of the FMMU areas configured for reading. Subdevices write data to their memory area
/// if the address received matches one of the FMMU areas configured for writing.
pub fn LRW(port: *nic.Port) void {
    _ = port;
}
/// Auto increment physical read multiple write.
/// A subdevice increments the address field. A subdevice writes data it has read to the EtherCAT
/// datagram when the address received is zero, otherwise it writes data to the memory area.
pub fn ARMW(port: *nic.Port) void {
    _ = port;
}
/// Configured address physical read multiple write.
pub fn FRMW(port: *nic.Port) void {
    _ = port;
}
