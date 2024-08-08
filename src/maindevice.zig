const std = @import("std");
const Port = @import("nic.zig").Port;
const pack_to_ecat = @import("nic.zig").pack_to_ecat;
const ecat_to_pack = @import("nic.zig").ecat_to_pack;
const pack_to_ecat_zeros = @import("nic.zig").pack_to_ecat_zeros;
const commands = @import("commands.zig");
const esc = @import("esc.zig");

pub const MainDeviceSettings = struct {
    timeout_recv_us: u32 = 2000,
};

pub const MainDevice = struct {
    port: *Port,
    settings: MainDeviceSettings,

    pub fn init(port: *Port, settings: MainDeviceSettings) MainDevice {
        return MainDevice{
            .port = port,
            .settings = settings,
        };
    }

    fn detect_subdevices(self: *MainDevice) !u16 {
        // disable alias address on all subdevices
        var data = [_]u8{0};
        var wkc = try commands.BWR(
            self.port,
            .{
                .position = 0,
                .offset = @intFromEnum(esc.RegisterMap.DL_control_enable_alias_address),
            },
            &data,
            self.settings.timeout_recv_us,
        );

        // command INIT on all subdevices twice
        var init_cmd = pack_to_ecat(esc.ALControlRegister{
            .state = .INIT,
            .ack = true, // ack errors
            .request_id = false,
        });
        wkc = try commands.BWR(
            self.port,
            .{
                .position = 0,
                .offset = @intFromEnum(esc.RegisterMap.AL_control),
            },
            &init_cmd,
            self.settings.timeout_recv_us,
        );

        var init_cmd2 = pack_to_ecat(esc.ALControlRegister{
            .state = .INIT,
            .ack = true, // ack errors
            .request_id = false,
        });
        wkc = try commands.BWR(
            self.port,
            .{
                .position = 0,
                .offset = @intFromEnum(esc.RegisterMap.AL_control),
            },
            &init_cmd2,
            self.settings.timeout_recv_us,
        );

        // count subdevices
        var data2 = [1]u8{0};
        wkc = try commands.BRD(
            self.port,
            .{
                .position = 0,
                .offset = 0,
            },
            &data2,
            self.settings.timeout_recv_us,
        );
        return wkc;
    }

    fn init_subdevices_to_default(self: *MainDevice) !u16 {

        // configure port forwarding settings
        var port_cmd = pack_to_ecat(esc.DLControlRegisterCompact{
            .forwarding_rule = true, // destroy non-ecat frames
            .temporary_loop_control = false, // permanent settings
            .loop_control_port0 = .auto,
            .loop_control_port1 = .auto,
            .loop_control_port2 = .auto,
            .loop_control_port3 = .auto,
        });
        const wkc = try commands.BWR(
            self.port,
            .{
                .position = 0,
                .offset = esc.RegisterMap.DL_control,
            },
            &port_cmd,
            self.settings.timeout_recv_us,
        );

        //
        return wkc;
    }

    /// Initialize the ethercat bus.
    ///
    /// Sets all subdevices to the INIT state.
    pub fn bus_init(self: *MainDevice) !u16 {
        var wkc = try self.detect_subdevices();
        if (wkc == 0) {
            return error.NoSubdevicesFound;
        }

        // read state of subdevices
        var state_check = pack_to_ecat_zeros(esc.ALStatusRegister);
        wkc = try commands.BRD(
            self.port,
            .{
                .position = 0,
                .offset = @intFromEnum(esc.RegisterMap.AL_status),
            },
            &state_check,
            self.settings.timeout_recv_us,
        );
        const state_check_res = ecat_to_pack(esc.ALStatusRegister, state_check);
        std.log.warn("state check: {}", .{state_check_res});

        return wkc;
    }
};
