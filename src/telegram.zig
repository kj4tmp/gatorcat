const std = @import("std");
const big = std.builtin.Endian.big;
const little = std.builtin.Endian.little;
const lossyCast = @import("std").math.lossyCast;
const assert = std.debug.assert;
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
    /// Subdevices write data to their memory area if the address received matches one of
    /// the FMMU areas configured for writing.
    LWR,
    /// Logical memory read write.
    /// A subdevice writes data it has read to the EtherCAT datagram if the address received
    /// matches one of the FMMU areas configured for reading. Subdevices write data to their memory area
    /// if the address received matches one of the FMMU areas configured for writing.
    LRW,
    /// Auto increment physical read multiple write.
    /// A subdevice increments the address field. A subdevice writes data it has read to the EtherCAT
    /// datagram when the address received is zero, otherwise it writes data to the memory area.
    ARMW,
    /// Configured address physical read multiple write.
    FRMW,
};

/// Mailbox Types
///
/// Ref: IEC 61158-4-12:2019 5.6
pub const MailboxType = enum(u4) {
    /// error
    ERR = 0x00,
    /// ADS over EtherCAT (AoE)
    AoE,
    /// Ethernet over EtherCAT (EoE)
    EoE,
    /// CAN Application Protocol over EtherCAT (CoE)
    CoE,
    /// File Access over EtherCAT (FoE)
    FoE,
    /// Servo Drive Profile over EtherCAT (SoE)
    SoE,
    /// Vendor Specfic over EtherCAT (VoE)
    VoE = 0x0f,
};

pub const MailboxErrorCode = enum(u16) {
    /// syntax of 6 octet mailbox header is wrong
    syntax = 0x01,
    /// specified mailbox protocol is not supported
    unsupported_protocol,
    /// channel field contains wrong value (a subdevice can ignore the channel field)
    invalid_channel,
    /// service in the mailbox protocol is not supported
    service_not_supported,
    /// mailbox protocl header of the mailbox protocol is wrong (without
    /// the 6 octet mailbox header)
    invalid_header,
    /// length of the recieved mailbox data is too short
    size_too_short,
    /// mailbox protocol cannot be processed because of limited resources,
    no_more_memory,
    /// length of the data is inconsistent
    invalid_size,
    /// mailbox service already in use
    service_in_work,
};

/// Mailbox Error Reply
///
/// Ref: IEC 61158-4-12:2019 5.6
pub const MailboxErrorReplyServiceData = struct {
    type: u16, // 0x01: mailbox command
    detail: MailboxErrorCode,
};

/// Mailbox Header
///
/// Ref: IEC 61158-4-12:2019 5.6
pub const MailboxHeader = packed struct {
    /// length of mailbox service data
    length: u16,
    address: StationAddress,
    /// reserved
    channel: u6,
    /// 0: lowest priority, 3: highest priority
    priority: u2,
    /// type of mailbox communication
    type: MailboxType,
    /// counter for the mailbox services
    /// zero is reserved. 1 is start value. next value after 7 is 1.
    ///
    /// Subdevice shall increment the counter for each new mailbox service. The maindevice
    /// shall check this for detection of lost mailbox services. The maindevice shall
    /// increment the counter value before retrying and the subdevice shall check for this
    /// for detection of repeat service. The subdevice shall not check the sequence of the
    /// counter value. The maindevice and the subdevice counters are independent.
    counter: u3,
    reserved: u1 = 0,
};

/// Mailbox
///
/// Mailbox communication data. Goes in data field of datagram.
///
/// Ref: IEC 61158-4-12:2019 5.6
pub const Mailbox = struct {
    header: MailboxHeader,
    /// mailbox service data
    data: []u8,
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
};

/// Max frame length
/// Includes header, but not FCS (intended to be the max allowable size to
/// give to a raw socket send().)
/// FCS is handled by hardware and not normally returned to user.
pub const max_frame_length = @divExact(@bitSizeOf(EthernetHeader), 8) + 1500;
pub const min_frame_length = 60;
