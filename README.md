# Zig EtherCAT MainDevice

An EtherCAT MainDevice written in pure Zig.

This library is in extremely early development.



## Notes

### zig annoyances

1. Cannot tell if my tests have run or not (even with --summary all)
2. Packed structs are not well described in the language reference
3. Where to I look for the implementation of flags.parse? root.zig? I don't know where
anything is!
4. Cannot have arrays in packed structs. (See SM and FMMU structs).
5. For loops over slices / arrays: I have to loop up the syntax every time.

### zig wins

big endian archs tests:

1. sudo apt install qemu-system-ppc qemu-utils binfmt-support qemu-user-static
2. zig build -fqemu -Dtarget=powerpc64-linux test --summary all


Designing an API that provides "views" to manipulate binary packed data.

Brace yourself, this is kind of a long post.

I am working on a library for an industrial protocol called EtherCAT.

I am trying to reach MVP quickly and simply, and add frills later.

The library essentially is just for manipulating special bits that are sent over an 
ethernet port from the "main device" (linux computer) to subdevices arranges in a loop
topology. The Maindevice sends frames, they travel through the subdevices, the subdevices
write to and read from the frame, and then the frame returns to the maindevice.

I think the minimum workflow for the user is the following:

1. Write a "bus configuration" that describes the subdevices to be controlled
2. Write a while loop that repeatedly sends / recvs frames with binary data. Read the returned frame, do some logic,
send a modified frame, repeat.

Questions:

1. The bus configuration should be easy to write, and not verbose. In the below pseudocode the user defines the input memory area of subdevices as a type (only existing at comptime). This has the advantage of very closely representing what is actually sent over the wire, in perhaps the simplest user-definable way possible.
The library can handle the endianness changes for the user and all those schenanigains.
Do you think this is a good idea? This perhaps uses the features of zig's comptime in the best possibly way, but may have the disadvantage of the user not being able to "read" the assembled process image type themself to reason about the code.


Here is some pseudo code:

```zig
const SubDevice = struct {

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
const EK1100Configuration = SubDevice{
    .vendor_id = 0x2,
    .product_code = 0x44c2c52,
    .revision_number = 0x110000,

    // this subdevice has no inputs or outputs
    .inputs = null,
    .outputs = null,
};

// this is a module with 8 digital outputs, bit packed into a
// single byte
const EL2008Configuration = SubDevice{
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
    subdevices: []SubDevice,
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


```

warning: pos: 0, vendor id: 0x2, product code: 0x44c2c52, revision: 0x110000
warning: pos: 1, vendor id: 0x2, product code: 0xcf23052, revision: 0x120000
warning: pos: 2, vendor id: 0x2, product code: 0xbe83052, revision: 0x130000
