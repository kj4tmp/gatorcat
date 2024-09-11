const std = @import("std");
const lossyCast = std.math.lossyCast;
const assert = std.debug.assert;
const big = std.builtin.Endian.big;
const little = std.builtin.Endian.little;

/// EtherCAT command, present in the EtherCAT datagram header.
pub const Command = enum(u8) {
    /// No operation.
    /// The subdevice ignores the command.
    NOP = 0x00,
    /// Auto increment physical read.
    /// A subdevice increments the address.
    /// A subdevice writes the data it has read to the EtherCAT datagram
    /// if the address received is zero.
    APRD,
    /// Auto increment physical write.
    /// A subdevice increments the address.
    /// A subdevice writes data to a memory area if the address received is zero.
    APWR,
    /// Auto increment physical read write.
    /// A subdevice increments the address.
    /// A subdevice writes the data it has read to the EtherCAT datagram and writes
    /// the newly acquired data to the same memory area if the received address is zero.
    APRW,
    /// Configured address physical read.
    /// A subdevice writes the data it has read to the EtherCAT datagram if its subdevice
    /// address matches one of the addresses configured in the datagram.
    FPRD,
    /// Configured address physical write.
    /// A subdevice writes data to a memory area if its subdevice address matches one
    /// of the addresses configured in the datagram.
    FPWR,
    /// Configured address physical read write.
    /// A subdevice writes the data it has read to the EtherCAT datagram and writes
    /// the newly acquired data to the same memory area if its subdevice address matches
    /// one of the addresses configured in the datagram.
    FPRW,
    /// Broadcast read.
    /// All subdevices write a logical OR of the data from the memory area and the data
    /// from the EtherCAT datagram to the EtherCAT datagram. All subdevices increment the
    /// position field.
    BRD,
    /// Broadcast write.
    /// All subdevices write data to a memory area. All subdevices increment the position field.
    BWR,
    /// Broadcast read write.
    /// All subdevices write a logical OR of the data from the memory area and the data from the
    /// EtherCAT datagram to the EtherCAT datagram; all subdevices write data to the memory area.
    /// BRW is typically not used. All subdevices increment the position field.
    BRW,
    /// Logical memory read.
    /// A subdevice writes data it has read to the EtherCAT datagram if the address received
    /// matches one of the FMMU areas configured for reading.
    LRD,
    /// Logical memory write.
    /// SubDevices write data to their memory area if the address received matches one of
    /// the FMMU areas configured for writing.
    LWR,
    /// Logical memory read write.
    /// A subdevice writes data it has read to the EtherCAT datagram if the address received
    /// matches one of the FMMU areas configured for reading. SubDevices write data to their memory area
    /// if the address received matches one of the FMMU areas configured for writing.
    LRW,
    /// Auto increment physical read multiple write.
    /// A subdevice increments the address field. A subdevice writes data it has read to the EtherCAT
    /// datagram when the address received is zero, otherwise it writes data to the memory area.
    ARMW,
    /// Configured address physical read multiple write.
    FRMW,
};

/// Position Address (Auto Increment Address)
pub const PositionAddress = packed struct(u32) {
    /// Each subdevice increments this address. The subdevice is addressed if position=0.
    autoinc_address: u16,
    /// local register address or local memory address of the ESC
    offset: u16,
};

pub const StationAddress = packed struct(u32) {
    /// The subdevice is addressed if its address corresponds to the configured station address
    /// or the configured station alias (if enabled).
    station_address: u16,
    /// local register address or local memory address of the ESC
    offset: u16,
};

pub const LogicalAddress = u32;

/// Datagram Header
///
/// Ref: IEC 61158-4-12:2019 5.4.1.2
pub const DatagramHeader = packed struct(u80) {
    /// service command, APRD etc.
    command: Command,
    /// used my maindevice to identify duplicate or lost datagrams
    idx: u8,
    /// auto-increment, configured station, or logical address
    /// when position addressing
    address: u32,
    /// length of following data, in bytes
    length: u11,
    /// reserved, 0
    reserved: u3 = 0,
    /// true when frame has circulated at least once, else false
    circulating: bool,
    /// multiple datagrams, true when more datagrams follow, else false
    next: bool,
    /// EtherCAT event request register of all subdevices combined with
    /// a logical OR. Two byte bitmask (IEC 61131-3 WORD)
    irq: u16,
};

/// Datagram
///
/// The IEC standard specifies the different commands
/// as different structures. However, the structure are all
/// very similar to they are combined here as one datagram.
///
/// The ETG standards appear to do combine them all too.
///
/// The only difference between the different commands is the addressing
/// scheme. They all have the same size.
///
/// Ref: IEC 61158-4-12:2019 5.4.1.2
pub const Datagram = struct {
    header: DatagramHeader,
    data: []u8,
    /// Working counter.
    /// The working counter is incremented if an EtherCAT device was successfully addressed
    /// and a read operation, a write operation or a read/write operation was executed successfully.
    /// Each datagram can be assigned a value for the corking counter that is expected after the
    /// telegram has passed through all devices. The maindevice can check whether an EtherCAT datagram
    /// was processed successfully by comparing the value to be expected for the working counter
    /// with the actual value of the working counter after it has passed through all devices.
    ///
    /// For a read command: if successful wkc+=1.
    /// For a write command: if write command successful wkc+=1.
    /// For a read/write command: if read command successful wkc+=1, if write command successful wkc+=2. If both wkc+=3.
    wkc: u16,

    /// Get length in bytes.
    /// Saturates to max u16.
    fn getLength(self: Datagram) u16 {
        var length: u16 = 0;
        length +|= @bitSizeOf(@TypeOf(self.header)) / 8;
        length +|= lossyCast(u16, self.data.len);
        length +|= @bitSizeOf(@TypeOf(self.wkc)) / 8;
        return length;
    }
    /// write calcuated fields (i.e. length field in header)
    fn calc(self: *Datagram) void {
        self.header.length = lossyCast(u11, self.data.len);
    }
};

/// EtherCAT Header
///
/// Ref: IEC 61158-4-12:2019 5.3.3
pub const EtherCATHeader = packed struct(u16) {
    /// length of the following datagrams (not including this header)
    length: u11,
    reserved: u1 = 0,
    /// ESC's only support EtherCAT commands (0x1)
    type: u4 = 0x1,
};

// TODO: EtherCAT frame structure containing network variables. Ref: IEC 61158-4-12:2019 5.3.3

/// EtherCAT Frame.
/// Must be embedded inside an Ethernet Frame.
///
/// Ref: IEC 61158-4-12:2019 5.3.3
pub const EtherCATFrame = struct {
    header: EtherCATHeader,
    datagrams: []Datagram,

    fn getLength(self: EtherCATFrame) u16 {
        var length: u16 = 0;
        length +|= @bitSizeOf(@TypeOf(self.header)) / 8;
        for (self.datagrams) |datagram| {
            length +|= datagram.getLength();
        }
        return length;
    }

    /// write calculated fields for this struct
    /// and all datagrams
    fn calc(self: *EtherCATFrame) void {
        var length: u11 = 0;
        for (self.datagrams) |*datagram| {
            length +|= lossyCast(u11, datagram.getLength());
            datagram.calc();
        }
        self.header.length = length;
    }
};

pub const EtherType = enum(u16) {
    UDP_ETHERCAT = 0x8000,
    ETHERCAT = 0x88a4,
};

// TODO: EtherCAT in UDP Frame. Ref: IEC 61158-4-12:2019 5.3.2

/// Ethernet Header
///
/// Ref: IEC 61158-4-12:2019 5.3.1
pub const EthernetHeader = packed struct(u112) {
    dest_mac: u48,
    src_mac: u48,
    ether_type: u16,
};

/// Ethernet Frame
///
/// This is what is actually sent on the wire.
///
/// It is a standard ethernet frame with EtherCAT data in it.
///
/// Ref: IEC 61158-4-12:2019 5.3.1
pub const EthernetFrame = struct {
    header: EthernetHeader,
    ethercat_frame: EtherCATFrame,
    padding: []const u8,

    /// calcuate the length of the frame in bytes
    /// without padding
    pub fn getLengthWithoutPadding(self: EthernetFrame) u16 {
        var length: u16 = 0;
        length +|= @bitSizeOf(@TypeOf(self.header)) / 8;
        length +|= self.ethercat_frame.getLength();
        return length;
    }

    /// Get required number of padding bytes
    /// for this frame.
    /// Assumes no existing padding.
    pub fn getRequiredPaddingLength(self: EthernetFrame) u16 {
        return @as(u16, min_frame_length) -| self.getLengthWithoutPadding();
    }

    pub fn getLengthWithPadding(self: EthernetFrame) u32 {
        var length: u32 = 0;
        length +|= @sizeOf(self.header);
        length +|= self.ethercat_frame.getLength();
        length +|= self.padding.len;
        return length;
    }

    /// write calcuated fields
    pub fn calc(self: *EthernetFrame) void {
        self.ethercat_frame.calc();
    }

    /// assign idx to first datagram for frame identification
    /// in nic
    pub fn assignIdx(self: *EthernetFrame, idx: u8) void {
        self.ethercat_frame.datagrams[0].header.idx = idx;
    }

    /// serialize this frame into the out buffer
    /// for tranmission on the line.
    ///
    /// Returns number of bytes written, or error.
    pub fn serialize(frame: *const EthernetFrame, out: []u8) !usize {
        var fbs = std.io.fixedBufferStream(out);
        var writer = fbs.writer();
        try writer.writeInt(u48, frame.header.dest_mac, big);
        try writer.writeInt(u48, frame.header.src_mac, big);
        try writer.writeInt(u16, frame.header.ether_type, big);
        const header_as_int: u16 = @bitCast(frame.ethercat_frame.header);
        try writer.writeInt(
            @TypeOf(header_as_int),
            header_as_int,
            little,
        );
        for (frame.ethercat_frame.datagrams) |datagram| {
            const datagram_header_as_int: u80 = @bitCast(datagram.header);
            try writer.writeInt(
                u80,
                datagram_header_as_int,
                little,
            );
            try writer.writeAll(datagram.data);
            try writer.writeInt(
                @TypeOf(datagram.wkc),
                datagram.wkc,
                little,
            );
        }
        try writer.writeAll(frame.padding);
        return fbs.getWritten().len;
    }

    /// deserialze bytes into datagrams
    pub fn deserialize(
        received: []const u8,
        out: []Datagram,
    ) !void {
        var fbs_reading = std.io.fixedBufferStream(received);
        var reader = fbs_reading.reader();

        const ethernet_header = EthernetHeader{
            .dest_mac = try reader.readInt(u48, big),
            .src_mac = try reader.readInt(u48, big),
            .ether_type = try reader.readInt(u16, big),
        };
        if (ethernet_header.ether_type != @intFromEnum(EtherType.ETHERCAT)) {
            return error.NotAnEtherCATFrame;
        }
        const header_as_int: u16 = try reader.readInt(u16, little);

        const ethercat_header: EtherCATHeader = @bitCast(header_as_int);

        const bytes_remaining = try fbs_reading.getEndPos() - try fbs_reading.getPos();
        const bytes_total = try fbs_reading.getEndPos();
        if (bytes_total < min_frame_length) {
            return error.InvalidFrameLengthTooSmall;
        }
        if (ethercat_header.length > bytes_remaining) {
            std.log.debug(
                "length field: {}, remaining: {}, end pos: {}",
                .{ ethercat_header.length, bytes_remaining, try fbs_reading.getEndPos() },
            );
            return error.InvalidEtherCATHeader;
        }

        for (out) |*out_datagram| {
            const datagram_header_as_int: u80 = try reader.readInt(u80, little);
            out_datagram.header = @bitCast(datagram_header_as_int);
            std.log.debug("datagram header: {}", .{out_datagram.header});
            if (out_datagram.header.length != out_datagram.data.len) {
                return error.CurruptedFrame;
            }
            const n_bytes_read = try reader.readAll(out_datagram.data);
            if (n_bytes_read != out_datagram.data.len) {
                return error.CurruptedFrame;
            }
            out_datagram.wkc = try reader.readInt(
                @TypeOf(out_datagram.wkc),
                little,
            );
        }
    }

    pub fn identifyFromBuffer(buf: []const u8) !u8 {
        var fbs = std.io.fixedBufferStream(buf);
        var reader = fbs.reader();
        var ethernet_header: EthernetHeader = undefined;
        ethernet_header.dest_mac = try reader.readInt(u48, big);
        ethernet_header.src_mac = try reader.readInt(u48, big);
        ethernet_header.ether_type = try reader.readInt(u16, big);
        if (ethernet_header.ether_type != @intFromEnum(EtherType.ETHERCAT)) {
            return error.NotAnEtherCATFrame;
        }
        const header_as_int: u16 = try reader.readInt(u16, little);
        const ethercat_header: EtherCATHeader = @bitCast(header_as_int);

        const bytes_remaining = try fbs.getEndPos() - try fbs.getPos();
        const bytes_total = try fbs.getEndPos();
        if (bytes_total < min_frame_length) {
            return error.InvalidFrameLengthTooSmall;
        }
        if (ethercat_header.length > bytes_remaining) {
            std.log.debug(
                "length field: {}, remaining: {}, end pos: {}",
                .{ ethercat_header.length, bytes_remaining, try fbs.getEndPos() },
            );
            return error.InvalidEtherCATHeader;
        }
        const datagram_header_as_int: u80 = try reader.readInt(u80, little);
        const datagram_header: DatagramHeader = @bitCast(datagram_header_as_int);
        return datagram_header.idx;
    }
};

test "ethernet frame serialization" {
    var data: [4]u8 = .{ 0x01, 0x02, 0x03, 0x04 };
    var datagrams: [1]Datagram = .{
        Datagram{
            .header = DatagramHeader{
                .command = Command.BRD,
                .idx = 123,
                .address = 0xABCDEF12,
                .length = 0,
                .circulating = false,
                .next = false,
                .irq = 0,
            },
            .data = &data,
            .wkc = 0,
        },
    };

    const padding = std.mem.zeroes([46]u8);
    var frame = EthernetFrame{
        .header = EthernetHeader{
            .dest_mac = 0x1122_3344_5566,
            .src_mac = 0xAABB_CCDD_EEFF,
            .ether_type = @intFromEnum(EtherType.ETHERCAT),
        },
        .ethercat_frame = EtherCATFrame{
            .header = EtherCATHeader{
                .length = 0,
            },
            .datagrams = &datagrams,
        },
        .padding = undefined,
    };
    frame.padding = padding[0..frame.getRequiredPaddingLength()];
    frame.calc();

    var out_buf: [max_frame_length]u8 = undefined;
    const serialized = out_buf[0..try frame.serialize(&out_buf)];
    const expected = [_]u8{
        // zig fmt: off
        0x11, 0x22, 0x33, 0x44, 0x55, 0x66, // src mac
        0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff, // dest mac
        0x88, 0xa4, // 0xa488 big endian
        0x10, 0b0001_0_000, // length=16, reserved=0, type=1
        0x07, // BRD
        123, // idx
        0x12, 0xEF, 0xCD, 0xAB, // address
        0x04, //length
        0x00, 0x00, 0x00,
        0x01, 0x02, 0x03, 0x04, // data
        // padding (30 bytes since 30 bytes above)
        0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00,

        // zig fmt: on
    };
    try std.testing.expectEqualSlices(u8, &expected, serialized);
}

test "ethernet frame serialization / deserialization" {

    var data: [4]u8 = .{ 0x01, 0x02, 0x03, 0x04 };
    var datagrams: [1]Datagram = .{
        Datagram{
            .header = DatagramHeader{
                .command = Command.BRD,
                .idx = 0,
                .address = 0xABCD,
                .length = 0,
                .circulating = false,
                .next = false,
                .irq = 0,
            },
            .data = &data,
            .wkc = 0,
        },
    };

    const padding = std.mem.zeroes([46]u8);
    var frame = EthernetFrame{
        .header = EthernetHeader{
            .dest_mac = 0xffff_ffff_ffff,
            .src_mac = 0xAAAA_AAAA_AAAA,
            .ether_type = @intFromEnum(EtherType.ETHERCAT),
        },
        .ethercat_frame = EtherCATFrame{
            .header = EtherCATHeader{
                .length = 0,
            },
            .datagrams = &datagrams,
        },
        .padding = undefined,
    };
    frame.padding = padding[0..frame.getRequiredPaddingLength()];
    frame.calc();

    var out_buf: [max_frame_length]u8 = undefined;
    const serialized = out_buf[0..try frame.serialize(&out_buf)];
    var allocator = std.testing.allocator;
    const serialize_copy = try allocator.dupe(u8, serialized);
    defer allocator.free(serialize_copy);

    var data2: [4]u8 = undefined;
    var datagrams2 = datagrams;
    datagrams2[0].data = &data2;

    try EthernetFrame.deserialize(serialize_copy, &datagrams2);

    try std.testing.expectEqualDeep(frame.ethercat_frame.datagrams, &datagrams2);
}


/// Max frame length
/// Includes header, but not FCS (intended to be the max allowable size to
/// give to a raw socket send().)
/// FCS is handled by hardware and not normally returned to user.
///
/// Constructed of 1500 payload and 14 byte header.
pub const max_frame_length = 1514;
comptime {
    assert(max_frame_length == @divExact(@bitSizeOf(EthernetHeader), 8) + 1500);
}
pub const min_frame_length = 60;
