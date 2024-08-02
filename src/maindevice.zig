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
    pub fn bus_init() !void {
        commands.BWR(Port, data: []const u8, timeout_us: u32)
    }
};

