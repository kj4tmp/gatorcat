const gcat = @import("gatorcat");

pub const eni = gcat.ENI{
    .subdevices = &.{
        beckhoff_EK1100,
        beckhoff_EL3314,
        beckhoff_EL3048,
        // beckhoff_EL7041_1000,
        beckhoff_EL2008,
        beckhoff_EL7041,
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

const beckhoff_EL3314 = gcat.ENI.SubDeviceConfiguration{
    .identity = .{
        .vendor_id = 0x2,
        .product_code = 0xcf23052,
        .revision_number = 0x120000,
    },
    .coe_startup_parameters = &.{
        .{
            .transition = .PS,
            .direction = .write,
            .index = 0x8000,
            .subindex = 0x2,
            .complete_access = false,
            .data = &.{2},
            .timeout_us = 10_000,
        },
    },
    .inputs_bit_length = 128,
};

const beckhoff_EL3048 = gcat.ENI.SubDeviceConfiguration{
    .identity = .{
        .vendor_id = 0x2,
        .product_code = 0xbe83052,
        .revision_number = 0x130000,
    },
    .inputs_bit_length = 256,
};

const beckhoff_EL7041_1000 = gcat.ENI.SubDeviceConfiguration{
    .identity = .{
        .vendor_id = 0x2,
        .product_code = 0x1b813052,
        .revision_number = 0x1503e8,
    },
    .inputs_bit_length = 64,
    .outputs_bit_length = 64,
    .coe_startup_parameters = &.{
        .{
            .transition = .PS,
            .direction = .write,
            .index = 0x1011,
            .subindex = 0x01,
            .complete_access = false,
            .data = &.{ 0x6c, 0x6f, 0x61, 0x64 }, // restore default params
            .timeout_us = 100_000,
        },
        .{
            .transition = .PS,
            .direction = .write,
            .index = 0x1c12, // RxPDO Assign
            .subindex = 0x0,
            .complete_access = true,
            .data = &.{ 0x03, 0x00, 0x00, 0x16, 0x02, 0x16, 0x04, 0x16 },
            .timeout_us = 10_000,
        },
        .{
            .transition = .PS,
            .direction = .write,
            .index = 0x1c13, // TxPDO Assign
            .subindex = 0x0,
            .complete_access = true,
            .data = &.{ 0x02, 0x00, 0x00, 0x1a, 0x03, 0x1a },
            .timeout_us = 10_000,
        },
    },
};

const beckhoff_EL2008 = gcat.ENI.SubDeviceConfiguration{
    .identity = .{
        .vendor_id = 0x2,
        .product_code = 0x7d83052,
        .revision_number = 0x100000,
    },
    .outputs_bit_length = 8,
};

const beckhoff_EL7031_0030 = gcat.ENI.SubDeviceConfiguration{
    .identity = .{
        .vendor_id = 0x2,
        .product_code = 0x1b773052,
        .revision_number = 0x0010001e,
    },
    .inputs_bit_length = 112,
    .outputs_bit_length = 64,
    .auto_config = .auto,
    .coe_startup_parameters = &.{
        // restore default params
        .{
            .transition = .PS,
            .direction = .write,
            .index = 0x1011,
            .subindex = 0x01,
            .complete_access = false,
            .data = &.{ 0x6c, 0x6f, 0x61, 0x64 }, // restore default params
            .timeout_us = 100_000,
        },
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
                0x0a, 0x1a, // AI standard: 4 bytes
                0x0c, 0x1a, // AI standard: 4 bytes
            },
            .timeout_us = 10_000,
        },
    },
};

const beckhoff_EL7041 = gcat.ENI.SubDeviceConfiguration{
    .identity = .{
        .vendor_id = 0x2,
        .product_code = 0x1b813052,
        .revision_number = 0x00190000,
    },
    .inputs_bit_length = 64,
    .outputs_bit_length = 64,
    .auto_config = .auto,
    .coe_startup_parameters = &.{
        .{
            .transition = .PS,
            .direction = .write,
            .index = 0x1011,
            .subindex = 0x01,
            .complete_access = false,
            .data = &.{ 0x6c, 0x6f, 0x61, 0x64 }, // restore default params
            .timeout_us = 100_000,
        },
        .{
            .transition = .PS,
            .direction = .write,
            .index = 0x1c12, // RxPDO Assign
            .subindex = 0x0,
            .complete_access = true,
            .data = &.{ 0x03, 0x00, 0x00, 0x16, 0x02, 0x16, 0x04, 0x16 },
            .timeout_us = 10_000,
        },
        .{
            .transition = .PS,
            .direction = .write,
            .index = 0x1c13, // TxPDO Assign
            .subindex = 0x0,
            .complete_access = true,
            .data = &.{ 0x02, 0x00, 0x00, 0x1a, 0x03, 0x1a },
            .timeout_us = 10_000,
        },
    },
};
