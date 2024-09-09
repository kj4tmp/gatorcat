const esc = @import("esc.zig");
const sii = @import("sii.zig");

pub const Transition = enum { IP, PS, PI, SP, SO, SI, OS, OP, OI, IB, BI, II, PP, SS };

// info gathered at runtime from bus,
// will be filled in when available
pub const SubDeviceRuntimeInfo = struct {
    autoinc_address: ?u16 = null,
    station_address: ?u16 = null,
    status: ?esc.ALStatusRegister = null,

    /// DL Info from ESC
    dl_info: ?esc.DLInformationRegister = null,

    /// first part of the SII
    info: ?sii.SubDeviceInfoCompact = null,

    /// SII General Catagory
    general: ?sii.CatagoryGeneral = null,

    /// Syncmanager configurations
    sms: ?esc.SMRegister = null,

    /// FMMU configurations
    fmmus: ?[16]?sii.FMMUFunction = null,

    /// name string from the SII
    name: ?sii.SIIString = null,
    /// order id from the SII, ex: EK1100
    order_id: ?sii.SIIString = null,
};

pub const SubDeviceConfig = struct {

    // information required to be entered by user
    vendor_id: u32,
    product_code: u32,
    revision_number: u32,
};

pub const BusConfiguration = struct {
    subdevices: []const SubDeviceConfig,
};
