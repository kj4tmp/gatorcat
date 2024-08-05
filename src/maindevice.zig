const std = @import("std");
const Port = @import("nic.zig").Port;
const pack_to_ecat = @import("nic.zig").pack_to_ecat;

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

    /// Initialize the ethercat bus.
    ///
    /// Sets all subdevices to the INIT state.
    pub fn bus_init(self: *MainDevice) !u16 {

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

        var init_cmd = pack_to_ecat(esc.ALControlRegister{
            .state = .INIT,
            .ack = true, // ack errors
            .request_id = false,
        });
        // command INIT on all subdevices
        wkc = try commands.BWR(
            self.port,
            .{
                .position = 0,
                .offset = @intFromEnum(esc.RegisterMap.AL_control),
            },
            &init_cmd,
            self.settings.timeout_recv_us,
        );

        if (wkc == 0) {
            return error.NoSubdevicesFound;
        }

        // read state of subdevices
        var state_check = pack_to_ecat(esc.ALStatusRegister{});
        wkc = try commands.BRD(self.port, .{.position = 0, .offset = esc.RegisterMap.AL_status}, data: []u8, timeout_us: u32)



        return wkc;
    }
};
