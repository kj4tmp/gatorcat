//! Bus Configuration
//!
//! Looks a lot like EtherCAT Network Configuration

const Transition = enum { IP, PS, PI, SP, SO, SI, OS, OP, OI, IB, BI, II, PP, SS };

const SubDevice = struct {
    vendor_id: u32,
    product_code: u32,
    revision_number: u32,

    process_data: ?ProcessData,
    coe_startup_parameters: []SDOCommand,

    const SDOCommand = struct {
        transitions: []Transition,
        timeout_ms: u32,
        index: u16,
        subindex: u8,
        data: []const u8,
    };

    const ProcessData = struct {
        input: ?type,
        output: ?type,
        input_pdos: []u32,
        output_pdos: []u32,
    };
};

pub const BusConfiguration = struct {
    subdevices: []SubDevice,
};
