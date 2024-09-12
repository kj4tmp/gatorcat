const ecm = @import("ecm");


// coupler
const EK1100 = struct {
    vendor_id: u32 = 0x2, 
    product_code: u32 = 0x44c2c52,
    revision_number: u32 = 0x110000,

    inputs: ?type = null,
    outputs: ?type = null,
};

// 4 channel thermocouple module
const EL3314 = struct {
    vendor_id: u32 = 0x2,
    product_code: u32 = 0xcf23052,
    revision_number: u32 = 0x120000,

    inputs: ?type = packed struct {
        TC1: u16,
        TC2: u16,
        TC3: u16,
        TC4: u16,
    },
    outputs: ?type = null
};

// 8 channel digital output module
const EL2008 = struct {
    vendor_id: u32 = 0x2,
    product_code: u32 = 0xcf23345,
    revision_number: u32 = 0x100000,

    inputs: ?type = null,
    outputs: ?type = packed struct {
        output_1: bool,
        output_2: bool,
        output_3: bool,
        output_4: bool,
        output_5: bool,
        output_6: bool,
        output_7: bool,
        output_8: bool,
    }

};




const beckhoff_EL3314 = ecm.SubDevice.PriorInfo{ };
const beckhoff_EL3048 = ecm.SubDevice.PriorInfo{ .vendor_id = 0x2, .product_code = 0xbe83052, .revision_number = 0x130000 };


const process_image = packed struct {

}