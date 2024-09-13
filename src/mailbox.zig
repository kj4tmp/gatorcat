const std = @import("std");
const Timer = std.time.Timer;
const ns_per_us = std.time.ns_per_us;
const assert = std.debug.assert;

const commands = @import("commands.zig");
const nic = @import("nic.zig");
const esc = @import("esc.zig");
const telegram = @import("telegram.zig");
const coe = @import("mailbox/coe.zig");


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
    _,
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

pub const StationAddress = u16;

/// Mailbox Header
///
/// Ref: IEC 61158-4-12:2019 5.6
pub const Header = packed struct(u48) {
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
    /// SubDevice shall increment the counter for each new mailbox service. The maindevice
    /// shall check this for detection of lost mailbox services. The maindevice shall
    /// increment the counter value before retrying and the subdevice shall check for this
    /// for detection of repeat service. The subdevice shall not check the sequence of the
    /// counter value. The maindevice and the subdevice counters are independent.
    cnt: u3,
    reserved: u1 = 0,
};

/// Mailbox
///
/// Mailbox communication data. Goes in data field of datagram.
///
/// Ref: IEC 61158-4-12:2019 5.6
pub const Mailbox = struct {
    mbx_header: Header,
    /// mailbox service data
    data: []u8,
};

/// The maximum mailbox size is limited by the maximum data that can be
/// read by a single datagram.
pub const max_size = 1486;
comptime {
    assert(max_size == telegram.max_frame_length - // 1514
        @divExact(@bitSizeOf(telegram.EthernetHeader), 8) - // u112
        @divExact(@bitSizeOf(telegram.EtherCATHeader), 8) - // u16
        @divExact(@bitSizeOf(telegram.DatagramHeader), 8) - // u80
        @divExact(@bitSizeOf(u16), 8)); // wkc
}

/// Send an Expedited SDO Read.
///
/// This is for data of length 1-4 bytes.
///
/// 1. Send sdo client expedited upload request until wkc = 1 or timeout
pub fn sdoReadExpedited(
    port: *nic.Port,
    station_address: u16,
    index: u16,
    subindex: u8,
    retries: u32,
    recv_timeout_us: u32,
    mbx_timeout_us: u32,
) !void {
    _ = mbx_timeout_us;
    _ = index;
    _ = subindex;

    // 1. send read

    // If mailbox in has got something in it, read mailbox to wipe it.
    const mbx_in: esc.SyncManagerAttributes = blk: {
        for (0..retries +% 1) |_| {
            const sm1_res = try commands.fprdPack(
                port,
                esc.SyncManagerAttributes,
                .{
                    .station_address = station_address,
                    .offset = @intFromEnum(esc.RegisterMap.SM1),
                },
                recv_timeout_us,
            );
            if (sm1_res.wkc == 1) {
                std.log.info("sm1 status: {}", .{sm1_res.ps.status});
                break :blk sm1_res.ps;
            }
        } else {
            return error.SubDeviceUnresponsive;
        }
        unreachable;
    };
    // mailbox configured?
    if (mbx_in.length == 0 or mbx_in.length > max_size) {
        return error.InvalidMailboxConfiguration;
    }

    if (mbx_in.status.mailbox_full) {
        var buf = std.mem.zeroes([max_size]u8); // yeet!
        for (0..retries +% 1) |_| {
            const wkc = try commands.fprd(
                port,
                .{
                    .station_address = station_address,
                    .offset = mbx_in.physical_start_address,
                },
                &buf,
                recv_timeout_us,
            );
            if (wkc == 1) {
                break;
            }
        } else {
            return error.SubDeviceUnresponsive;
        }
    }

    const mbx_out: esc.SyncManagerAttributes = blk: {
        for (0..retries +% 1) |_| {
            const sm0_res = try commands.fprdPack(
                port,
                esc.SyncManagerAttributes,
                .{
                    .station_address = station_address,
                    .offset = @intFromEnum(esc.RegisterMap.SM0),
                },
                recv_timeout_us,
            );
            if (sm0_res.wkc == 1) {
                std.log.info("sm1 status: {}", .{sm0_res.ps.status});
                break :blk sm0_res.ps;
            }
        } else {
            return error.SubDeviceUnresponsive;
        }
        unreachable;
    };
    // mailbox configured?
    if (mbx_out.length == 0 or mbx_out.length > max_size) {
        return error.InvalidMailboxConfiguration;
    }
}

// pub fn readMailbox(
//     port: *nic.Port,
//     station_address: u16,
//     retries: u32,
//     recv_timeout_us: u32,
//     mbx_timeout_us: u32,
// ) ![max_size]u8 {
//     _ = retries;
//     var timer = try Timer.start();

//     const mbx_in: esc.SyncManagerAttributes = blk: {
//         while (timer.read() < mbx_timeout_us * ns_per_us) {
//             const sm1_res = try commands.fprdPack(
//                 port,
//                 esc.SyncManagerAttributes,
//                 .{
//                     .station_address = station_address,
//                     .offset = @intFromEnum(esc.RegisterMap.SM1),
//                 },
//                 recv_timeout_us,
//             );
//             if (sm1_res.wkc == 1) {
//                 if (sm1_res.ps.status.mailbox_full) {
//                     break :blk sm1_res.ps;
//                 }
//             }
//         } else {
//             return error.Timeout;
//         }
//     };
//     assert(mbx_in.status.mailbox_full);

//     // mailbox configured?
//     if (mbx_in.length == 0 or mbx_in.length > max_size) {
//         return error.InvalidMailboxConfiguration;
//     }
// }



pub const MailboxContentType = enum {
    sdo_download_expedited_or_normal_response,
    sdo_download_segment_response,

    sdo_upload_expedited_response,
    sdo_upload_normal_response,
    sdo_upload_segment_response,

    abort_sdo_transfer_request,

    get_od_list_response,
    get_object_description_response,
    get_entry_description_response,
    sdo_info_error,

    emergency_request,
};

pub const MailboxContent = union {



    pub fn identify(buf: []const u8) {
        
    }

}

// Messages that can be read from mailbox in.
//
// TODO: other mailbox protocols?
// pub const MailboxMessage = union(enum) {
//     sdo_download_expedited_request: SDODownloadExpeditedRequest,
//     sdo_download_expedited_response: SDODownloadExpeditedResponse,
//     // // sdo_download_normal_request: SDODownloadNormalRequest,
//     // sdo_download_normal_response: SDODownloadNormalResponse,
//     // sdo_download_segment_response: SDODownloadSegmentResponse,
//     // sdo_upload_expedited_response: SDOUploadExpeditedResponse,
//     // sdo_upload_normal_response: SDOUploadNormalResponse,
//     // sdo_upload_segment_response: SDOUploadSegmentResponse,
//     // abort_sdo_transfer_request: AbortSDOTransferRequest,
//     // get_od_list_response: GetODListResponse,
//     // get_object_description_response: GetObjectDescriptionResponse,
//     // get_entry_description_response: GetEntryDescriptionResponse,
//     // sdo_info_error_request: SDOInfoErrorRequest,
//     emergency_request: EmergencyRequest,
//     // rxpdo: RxPDOTransmission,
//     // txpdo: TxPDOTransmission,
//     // rxpdo_remote_request: RxPDORemoteTransmissionRequest,
//     // txpdo_remote_request: TxPDORemoteTransmissionRequest,

//     pub fn deserialize(buf: []const u8) !MailboxMessage {
//         var fbs = std.io.fixedBufferStream(buf);
//         var reader = fbs.reader();

//         const mbx_header = try wire.packFromECatReader(Header, &reader);

//         if (mbx_header.length > buf.len - @divExact(@bitSizeOf(Header), 8)) {
//             return error.InvalidHeaderLength;
//         }

//         switch (mbx_header.type) {
//             _ => return error.InvalidProtocol,
//             .ERR, .AoE, .EoE, .FoE, .SoE, .VoE => return error.UnsupportedMailboxProtocol,
//             .CoE => {
//                 const coe_header = try wire.packFromECatReader(Header, &reader);

//                 switch (coe_header.service) {
//                     _ => return error.InvalidService,
//                     .sdo_request => {
//                         const sdo_header = try wire.packFromECatReader(SDOHeader, &reader);

//                         switch (sdo_header.command) {
//                             .download_request => {
//                                 switch (sdo_header.transfer_type) {
//                                     .expedited => {
//                                         fbs.reset();
//                                         const sdo_download_expedited_request = try wire.packFromECatReader(SDODownloadExpeditedRequest, &reader);
//                                         return MailboxMessage{ .sdo_download_expedited_request = sdo_download_expedited_request };
//                                     },
//                                     .normal => {
//                                         return error.NotImplemented;
//                                     },
//                                 }
//                             },
//                         }
//                     },
//                     // .sdo_response => {
//                     //     const sdo_header = try wire.packFromECatReader(SDOHeader, &reader);
//                     //     switch (sdo_header.command) {
//                     //         .download_response => {
//                     //             fbs.reset();
//                     //             const sdo_download_expedited_response = try wire.packFromECatReader(SDODownloadExpeditedResponse, &reader);
//                     //             return MailboxMessage{ .sdo_download_expedited_response = sdo_download_expedited_response };
//                     //         },
//                     //     }
//                     // },
//                     .emergency => {
//                         fbs.reset();
//                         const emergency_message = try wire.packFromECatReader(EmergencyRequest, &reader);
//                         return MailboxMessage{ .emergency_request = emergency_message };
//                     },
//                     .sdo_response => error.NotImplemented,
//                     .tx_pdo => return error.NotImplemented,
//                     .rx_pdo => return error.NotImplemented,
//                     .tx_pdo_remote_request => return error.NotImplemented,
//                     .rx_pdo_remote_request => return error.NotImplemented,
//                     .sdo_info => return error.NotImplemented,
//                 }
//             },
//         }
//         unreachable;
//     }
// };

// test "deserialize emergency message" {
//     const expected = EmergencyRequest{
//         .mbx_header = .{
//             .length = 10,
//             .address = 0x1001,
//             .channel = 0,
//             .priority = 0x03,
//             .type = .CoE,
//             .cnt = 3,
//         },
//         .coe_header = .{
//             .number = 0,
//             .service = .emergency,
//         },
//         .error_code = 0x1234,
//         .error_register = 23,
//         .data = 12345,
//     };
//     const buf = nic.eCatFromPack(expected);
//     var zero_buf = std.mem.zeroes([100]u8);
//     @memcpy(zero_buf[0..16], buf[0..16]);
//     const actual = try MailboxMessage.deserialize(&zero_buf);

//     try std.testing.expectEqualDeep(expected, actual.emergency_request);
// }

// test "deserialized sdo download expedited request" {
//     const expected = SDODownloadExpeditedRequest{
//         .mbx_header = .{
//             .length = 10,
//             .address = 0x1001,
//             .channel = 0,
//             .priority = 0x01,
//             .type = .CoE,
//             .cnt = 2,
//         },
//         .coe_header = .{
//             .number = 0,
//             .service = .sdo_request,
//         },
//         .sdo_header = .{
//             .size_indicator = true,
//             .transfer_type = .expedited,
//             .data_set_size = .one_octet,
//             .complete_access = false,
//             .command = .download_request,
//             .index = 0x6000,
//             .subindex = 34,
//         },
//         .data = @bitCast([4]u8{ 1, 2, 3, 4 }),
//     };
//     const buf = nic.eCatFromPack(expected);
//     var zero_buf = std.mem.zeroes([100]u8);
//     @memcpy(zero_buf[0..16], buf[0..16]);
//     const actual = try MailboxMessage.deserialize(&zero_buf);

//     try std.testing.expectEqualDeep(expected, actual.sdo_download_expedited_request);
// }

// fn deserializeMailboxData()

// fn readMailbox(port: *nic.Port) !void {
//     var buf = std.mem.zeroes([1486]u8); // yeet!
//     // read raw mailbox data into the buffer
//     read(port, &buf);
//     _ = deserializeMialboxData(&buf);
// }
