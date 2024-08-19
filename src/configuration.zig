//! Bus Configuration
//!
//! Looks a lot like EtherCAT Network Information (ENI).
//!
//! Ref: ETG.2100

pub const Transition = enum { IP, PS, PI, SP, SO, SI, OS, OP, OI, IB, BI, II, PP, SS };

pub const Subdevice = struct {

    // this information serves only to identify the subdevice
    // in the network (provided by subdevice datasheet)
    vendor_id: u32,
    product_code: u32,
    revision_number: u32,
};

pub const BusConfiguration = struct {
    subdevices: []Subdevice,
};
