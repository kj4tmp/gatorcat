const std = @import("std");
const Port = @import("nic.zig").Port;
const telegram = @import("telegram.zig");
const eCatFromPack = @import("nic.zig").eCatFromPack;
const packFromECat = @import("nic.zig").packFromECat;
const zerosFromPack = @import("nic.zig").zerosFromPack;
const commands = @import("commands.zig");
const esc = @import("esc.zig");
const sii = @import("sii.zig");
const BusConfiguration = @import("configuration.zig").BusConfiguration;

pub const MainDeviceSettings = struct {
    timeout_recv_us: u32 = 2000,
};

pub const MainDevice = struct {
    port: *Port,
    settings: MainDeviceSettings,
    bus_config: ?BusConfiguration,

    pub fn init(
        port: *Port,
        settings: MainDeviceSettings,
        bus_config: ?BusConfiguration,
    ) MainDevice {
        return MainDevice{
            .port = port,
            .settings = settings,
            .bus_config = bus_config,
        };
    }

    /// Initialize the ethercat bus.
    ///
    /// Sets all subdevices to the INIT state.
    pub fn bus_init(self: *MainDevice) !u16 {
        // disable alias address on all subdevices
        var data = [_]u8{0};
        var wkc = try commands.BWR(
            self.port,
            .{
                .autoinc_address = 0,
                .offset = @intFromEnum(esc.RegisterMap.DL_control_enable_alias_address),
            },
            &data,
            self.settings.timeout_recv_us,
        );

        // open all the ports
        var port_cmd = eCatFromPack(esc.DLControlRegisterCompact{
            .forwarding_rule = true, // destroy non-ecat frames
            .temporary_loop_control = false, // permanent settings
            .loop_control_port0 = .auto,
            .loop_control_port1 = .auto,
            .loop_control_port2 = .auto,
            .loop_control_port3 = .auto,
        });
        wkc = try commands.BWR(
            self.port,
            .{
                .autoinc_address = 0,
                .offset = @intFromEnum(esc.RegisterMap.DL_control),
            },
            &port_cmd,
            self.settings.timeout_recv_us,
        );

        // command INIT on all subdevices, twice
        // SOEM does this, something about netX100

        for (0..1) |_| {
            var init_cmd = eCatFromPack(esc.ALControlRegister{
                .state = .INIT,
                .ack = true, // ack errors
                .request_id = false,
            });
            wkc = try commands.BWR(
                self.port,
                .{
                    .autoinc_address = 0,
                    .offset = @intFromEnum(esc.RegisterMap.AL_control),
                },
                &init_cmd,
                self.settings.timeout_recv_us,
            );
        }

        // // count subdevices
        // wkc = try commands.BRD(
        //     self.port,
        //     .{
        //         .autoinc_address = 0,
        //         .offset = 0,
        //     },
        //     &.{0},
        //     self.settings.timeout_recv_us,
        // );
        // std.log.info("detected {} subdevices", .{wkc});
        // if (wkc == 0) {
        //     return error.NoSubdevicesFound;
        // }

        // read state of subdevices
        var state_check = zerosFromPack(esc.ALStatusRegister);
        wkc = try commands.BRD(
            self.port,
            .{
                .autoinc_address = 0,
                .offset = @intFromEnum(esc.RegisterMap.AL_status),
            },
            &state_check,
            self.settings.timeout_recv_us,
        );
        const state_check_res = packFromECat(esc.ALStatusRegister, state_check);
        std.log.warn("state check: {}", .{state_check_res});

        return wkc;
    }

    // pub fn scan(self: *MainDevice) !void {
    //     const wkc = try self.detect_subdevices();

    //     if (wkc == 0) {
    //         return error.NoSubdevicesFound;
    //     }
    //     var i: u16 = 0;
    //     while (i < wkc) : (i += 1) {
    //         const identity = try sii.readSII_ps(
    //             self.port,
    //             sii.SubdeviceIdentity,
    //             calc_autoinc_addr(i),
    //             @intFromEnum(sii.ParameterMap.vendor_id),
    //             3,
    //             self.settings.timeout_recv_us,
    //             10000,
    //         );
    //         std.log.info(
    //             "pos: {}, vendor id: 0x{x}, product code: 0x{x}, revision: 0x{x}",
    //             .{
    //                 i,
    //                 identity.vendor_id,
    //                 identity.product_code,
    //                 identity.revision_number,
    //             },
    //         );
    //     }
    // }
};

/// Calcuate the auto increment address of a subdevice
/// for commands which use position addressing.
///
/// The position parameter is the the subdevices position
/// in the ethercat bus. 0 is the maindevice. 1 is the first
/// subdevice (the first subdevice to see the frame). Etc.
fn calc_autoinc_addr(position: u16) u16 {
    var rval: u16 = 0;
    rval -%= position;
    return rval;
}

test "calc_autoinc_addr" {
    std.testing.expectEqual(@as(u16, 0), calc_autoinc_addr(0));
    std.testing.expectEqual(@as(u16, 65535), calc_autoinc_addr(1));
    std.testing.expectEqual(@as(u16, 65534), calc_autoinc_addr(2));
    std.testing.expectEqual(@as(u16, 65533), calc_autoinc_addr(3));
    std.testing.expectEqual(@as(u16, 65532), calc_autoinc_addr(4));
}
