const std = @import("std");
const Timer = std.time.Timer;
const ns_per_us = std.time.ns_per_us;
const nic = @import("nic.zig");
const esc = @import("esc.zig");

const Port = nic.Port;
const commands = @import("commands.zig");

pub const SIIReaderSettings = struct {
    retries: u32,
    recv_timeout_us: u32,
    eeprom_timeout_us: u32,
};

pub const SIIReader = struct {
    state: State = .init,
    port: *Port,
    settings: SIIReaderSettings,
    autoinc_address: u16,
    eeprom_address: u16,
    result: [4]u8 = [4]u8{ 0, 0, 0, 0 },

    const State = enum { init, read_cmd, read_fetch, done };

    pub fn init(
        port: *Port,
        autoinc_address: u16,
        eeprom_address: u16,
        settings: SIIReaderSettings,
    ) SIIReader {
        return SIIReader{
            .port = port,
            .autoinc_address = autoinc_address,
            .eeprom_address = eeprom_address,
            .settings = settings,
        };
    }

    /// Call this until it returns .done.
    /// If it returns an error you should stop calling it.
    pub fn cycle(self: *SIIReader) !State {
        switch (self.state) {
            .init => {
                return try self.doInit();
            },
            .read_cmd => {
                return try self.doReadCmd();
            },
            .read_fetch => {
                return try self.doReadFetch();
            },
            .done => {
                return State.done;
            },
        }
    }

    fn doInit(self: *SIIReader) !State {
        std.debug.assert(self.state == .init);

        // set eeprom access to main device
        for (0..self.settings.retries) |_| {
            const wkc = try commands.APWR_ps(
                self.port,
                esc.SIIAccessRegisterCompact{
                    .owner = .ethercat_DL,
                    .lock = false,
                },
                .{
                    .autoinc_address = self.autoinc_address,
                    .offset = @intFromEnum(esc.RegisterMap.SII_access),
                },
                self.settings.recv_timeout_us,
            );
            if (wkc == 1) {
                break;
            }
        } else {
            return error.SubdeviceUnresponsive;
        }

        //transition to read_cmd
        self.state = .read_cmd;
        return self.state;
    }
    fn doReadCmd(self: *SIIReader) !State {
        std.debug.assert(self.state == .read_cmd);

        // ensure there is a rising edge in the read command by first sending zeros
        for (0..self.settings.retries) |_| {
            var data = nic.zerosFromPack(esc.SIIControlStatusRegister);
            const wkc = try commands.APWR(
                self.port,
                .{
                    .autoinc_address = self.autoinc_address,
                    .offset = @intFromEnum(esc.RegisterMap.SII_control_status),
                },
                &data,
                self.settings.recv_timeout_us,
            );
            if (wkc == 1) {
                break;
            }
        } else {
            return error.SubdeviceUnresponsive;
        }

        // send read command
        for (0..self.settings.retries) |_| {
            const wkc = try commands.APWR_ps(
                self.port,
                esc.SIIControlStatusAddressRegister{
                    .write_access = false,
                    .EEPROM_emulation = false,
                    .read_size = .four_bytes,
                    .address_algorithm = .one_byte_address,
                    .read_operation = true, // <-- cmd
                    .write_operation = false,
                    .reload_operation = false,
                    .checksum_error = false,
                    .device_info_error = false,
                    .command_error = false,
                    .write_error = false,
                    .busy = false,
                    .sii_address = self.eeprom_address,
                },
                .{
                    .autoinc_address = self.autoinc_address,
                    .offset = @intFromEnum(esc.RegisterMap.SII_control_status),
                },
                self.settings.recv_timeout_us,
            );
            if (wkc == 1) {
                break;
            }
        } else {
            return error.SubdeviceUnresponsive;
        }

        var timer = try Timer.start();
        // wait for eeprom to be not busy
        while (timer.read() < self.settings.eeprom_timeout_us * ns_per_us) {
            const sii_status = try commands.APRD_ps(
                self.port,
                esc.SIIControlStatusRegister,
                .{
                    .autoinc_address = self.autoinc_address,
                    .offset = @intFromEnum(
                        esc.RegisterMap.SII_control_status,
                    ),
                },
                self.settings.recv_timeout_us,
            );

            if (sii_status.wkc != 1) {
                continue;
            }
            if (sii_status.ps.busy) {
                continue;
            } else {
                // check for eeprom nack
                if (sii_status.ps.command_error) {
                    return error.eepromCommandError;
                }
                break;
            }
        } else {
            return error.eepromTimeout;
        }

        self.state = .read_fetch;
        return self.state;
    }

    fn doReadFetch(self: *SIIReader) !State {
        std.debug.assert(self.state == .read_fetch);

        // attempt read 3 times
        for (0..self.settings.retries) |_| {
            var data = [4]u8{ 0, 0, 0, 0 };
            const wkc = try commands.APRD(
                self.port,
                .{
                    .autoinc_address = self.autoinc_address,
                    .offset = @intFromEnum(
                        esc.RegisterMap.SII_data,
                    ),
                },
                &data,
                self.settings.recv_timeout_us,
            );
            if (wkc == 1) {
                self.state = .done;
                self.result = data;
                return self.state;
            }
        } else {
            return error.SubdeviceUnresponsive;
        }
    }
};

pub fn readSII4Byte_ps(
    port: *Port,
    comptime packed_struct_type: type,
    autoinc_address: u16,
    eeprom_address: u16,
    timeout_us: u32,
) !packed_struct_type {
    comptime std.debug.assert(@bitSizeOf(packed_struct_type) == 32);
    var timer = try Timer.start();

    var reader = SIIReader.init(
        port,
        autoinc_address,
        eeprom_address,
        .{
            .eeprom_timeout_us = 3000,
            .recv_timeout_us = 3000,
            .retries = 3,
        },
    );
    while (timer.read() < timeout_us * ns_per_us) {
        if (try reader.cycle() == .done) {
            return nic.packFromECat(packed_struct_type, reader.result);
        }
    } else {
        return error.Timeout;
    }
}
