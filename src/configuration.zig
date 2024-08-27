//! Bus Configuration
//!
//! Looks a lot like EtherCAT Network Information (ENI).
//!
//! Ref: ETG.2100

const esc = @import("esc.zig");

pub const Transition = enum { IP, PS, PI, SP, SO, SI, OS, OP, OI, IB, BI, II, PP, SS };

pub const SubdeviceRuntimeInfo = struct {
    // info gathered at runtime from bus,
    // will be filled in when available
    autoinc_address: ?u16 = null,
    station_address: ?u16 = null,
    status: ?esc.ALStatusRegister = null,
};

pub const Subdevice = struct {

    // information required to be entered by user
    vendor_id: u32,
    product_code: u32,
    revision_number: u32,
};

pub const BusConfiguration = struct {
    subdevices: []const Subdevice,
};
