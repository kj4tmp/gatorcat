//! The EtherCAT State Machine (ESM).
//!
//! Ref: IEC 61158-6-12:2019 6.4.1.4

const std = @import("std");

const esc = @import("../esc.zig");
const sim = @import("../sim.zig");

pub const ESM = @This();
state: esc.ALStatusRegister = .{
    .err = false,
    .id_loaded = false,
    .state = .INIT,
    .status_code = .no_error,
},

pub fn initTick(self: *ESM, phys_mem: *sim.Subdevice.PhysMem) void {
    sim.writeRegister(self.state, .AL_status, phys_mem);
    sim.writeRegister(esc.ALControlRegister{
        .ack = false,
        .request_id = false,
        .state = ._none,
    }, .AL_control, phys_mem);
}

pub fn tick(self: *ESM, phys_mem: *sim.Subdevice.PhysMem) void {
    const control = sim.readRegister(esc.ALControlRegister, .AL_control, phys_mem);
    self.state = sim.readRegister(esc.ALStatusRegister, .AL_status, phys_mem);

    _ = control;

    // TODO: implement ethercat state machine
    switch (self.state.state) {
        .INIT => {},
        .PREOP => {},
        .SAFEOP => {},
        .OP => {},
        .BOOT => {},
        _ => unreachable,
    }

    sim.writeRegister(std.mem.zeroes(esc.ALControlRegister), .AL_control, phys_mem);
}

// The ID Info primitive from the ethercat state machine.
// Ref: IEC 61158-6-12:2019 6.4.1.3.2
// pub fn idInfo(idRequested: bool, idSupported: bool, phys_mem: *sim.Subdevice.PhysMem) void {
//     if (idRequested and idSupported) {}
// }
