const std = @import("std");
const Port = @import("nic.zig").Port;
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
    /// Sets all subdevices to the init state.
    pub fn bus_init(self: *MainDevice) !void {

        // disable alias address
        commands.BWR(
            self.port,
            .{
                .position = 0,
                .offset = esc.RegisterMap.DL_control_enable_alias_address,
            },
            &[_]u8{0},
            self.settings.timeout_recv_us,
        );

        // command init state
        const init_cmd = esc.ALControlRegister{
            .state = .INIT,
            .ack = true,
            .request_id = false,
        };
    }
};
