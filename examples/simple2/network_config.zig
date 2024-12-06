const gcat = @import("gatorcat");

pub const eni = gcat.ENI{
    .subdevices = &.{
        beckhoff_EK1100,
        beckhoff_EL7031_0030,
    },
};

const beckhoff_EK1100 = gcat.ENI.SubDeviceConfiguration{
    .identity = .{
        .vendor_id = 0x2,
        .product_code = 0x44c2c52,
        .revision_number = 0x110000,
    },
};

const beckhoff_EL7031_0030 = gcat.ENI.SubDeviceConfiguration{
    .identity = .{
        .vendor_id = 0x2,
        .product_code = 0x1b773052,
        .revision_number = 0x0010001e,
    },
    .inputs_bit_length = 128,
    .outputs_bit_length = 64,
    .auto_config = .coe,
    .coe_startup_parameters = &.{
        // restore default params
        // .{
        //     .transition = .PS,
        //     .direction = .write,
        //     .index = 0x1011,
        //     .subindex = 0x01,
        //     .complete_access = false,
        //     .data = &.{ 0x6c, 0x6f, 0x61, 0x64 }, // restore default params
        //     .timeout_us = 100_000,
        // },
        // .{
        //     .transition = .PS,
        //     .direction = .write,
        //     .index = 0xf081, // download revision
        //     .subindex = 0x1,
        //     .complete_access = false,
        //     .data = &.{ 0x1e, 0x00, 0x10, 0x00 },
        //     .timeout_us = 10_000,
        // },
        // .{
        //     .transition = .PS,
        //     .direction = .write,
        //     .index = 0x10f3, // undocumented
        //     .subindex = 0x5,
        //     .complete_access = false,
        //     .data = &.{ 0x01, 0x00 },
        //     .timeout_us = 10_000,
        // },
        .{
            .transition = .PS,
            .direction = .write,
            .index = 0x1c12, // RxPDO Assign
            .subindex = 0x0,
            .complete_access = true,
            .data = &.{
                0x03, 0x00, // 3 PDOs
                0x00, 0x16, // encoder control: 4 bytes
                0x02, 0x16, // STM control: 2 bytes
                0x04, 0x16, // STM velocity: 2 bytes
            },
            .timeout_us = 10_000,
        },
        .{
            .transition = .PS,
            .direction = .write,
            .index = 0x1c13, // TxPDO Assign
            .subindex = 0x0,
            .complete_access = true,
            .data = &.{
                0x04, 0x00, // 4 PDOs
                0x00, 0x1a, // encoder: 6 bytes
                0x03, 0x1a, // STM status: 2 bytes
                0x0a, 0x1a, // AI standard: 4 bytes
                0x0c, 0x1a, // AI standard: 4 bytes
            },
            .timeout_us = 10_000,
        },
    },
};
