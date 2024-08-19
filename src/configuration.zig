//! Bus Configuration
//!
//! Looks a lot like EtherCAT Network Configuration

// const Transition = enum { IP, PS, PI, SP, SO, SI, OS, OP, OI, IB, BI, II, PP, SS };

// const SubDevice = struct {
//     vendor_id: u32,
//     product_code: u32,
//     revision_number: u32,

//     process_data: ?ProcessData,
//     coe_startup_parameters: []SDOCommand,

//     const SDOCommand = struct {
//         transitions: []Transition,
//         timeout_ms: u32,
//         index: u16,
//         subindex: u8,
//         data: []const u8,
//     };

//     const ProcessData = struct {
//         input: ?type,
//         output: ?type,
//         input_pdos: []u32,
//         output_pdos: []u32,
//     };
// };

const Subdevice = struct {

    // this information serves only to identify the subdevice
    // in the network (provided by subdevice datasheet)
    vendor_id: u32,
    product_code: u32,
    revision_number: u32,

    /// a packed struct to represent data that
    /// is produced by the subdevice and not intended
    /// to be manipulated by the user (the subdevice writes this to the frames)
    ///
    /// defined in datasheet of subdevice
    inputs: ?type,

    /// a packed struct to represent data that
    /// is read from the frames by the subdevice, should be
    /// set by the user before sending each frame
    ///
    /// defined in datasheet of subdevice
    outputs: ?type,
};

// an example configuraion for a subdevice
const EK1100Configuration = Subdevice{
    .vendor_id = 0x2,
    .product_code = 0x44c2c52,
    .revision_number = 0x110000,

    // this subdevice has no inputs or outputs
    .inputs = null,
    .outputs = null,
};

// this is a module with 8 digital outputs, bit packed into a
// single byte
const EL2008Configuration = Subdevice{
    .vendor_id = 0x2,
    .product_code = 0xaa34da,
    .revision_number = 0x100000,

    .outputs = packed struct {
        fill_valve: bool, // when this is true the fill valve is open
        vent_valve: bool, // then this is true the vent valve is open
        not_used: u6,
    },
};

pub const BusConfiguration = struct {
    // the order of the subdevices in the ring is based on the order in
    // this array
    subdevices: []Subdevice,
    // bunch of other configuration parameters etc.
};

pub const MainDevice = struct {

    // each of the subdevices input and output data is 
    // mapped to a place in contiguous memory
    // the process image is the concatenation of all of this data
    // the type is perhaps created at comptime
    process_image: some_comtpime_type,
    bus_configuration: BusConfiguration,
};


pub fn main() !void {

    // user defines what they expect the bus to look like
    const my_bus_configuration: BusConfiguration = ...;

    // user makes a main device
    const my_main_device: MainDevice = ...;

    // maindevice contacts subdevices and 
    // verifies the bus contains only the subdevices
    // defined in the bus configuration
    try my_main_device.validateBusConfiguration(my_bus_configuration);

    // begin controlling the subdevices
    while (true) {
        
        // recv frames to get inputs of subdevices
        try main_device.recv_frames();

        // do the business logic
        // for example, open a fill valve when the pressure is too low
        if (main_device.subdevices.pressure_transducer_module.inputs.tank_pressure < 100) {
            main_device.subdevices.digital_output_module.outputs,fill_valve = true;
        } else {
            main_device.subdevices.digital_output_module.outputs.fill_valve = false;
        }

        // send frames to command subdevice outputs
        try main_device.send_frames();
        sleep_microseconds(1000);
    }

}


