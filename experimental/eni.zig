//! EtherCAT Network Information
//!
//! Ref: ETG.2100

const telegram = @import("telegram.zig");

const String = []const u8;
const HexBinary = []u8;
// TODO: double check size of hex dec value
const HexDecValue = u16;

const EtherType = enum(u16) {
    ethercat = 0x88a4,
    udp_ethercat = 0x8000,
};

const InitECatCmds = struct { ecat_cmds: []ECatCmd };

const ECatCmd = struct {
    //transitions: []Transition,
    before_subdevice: ?bool,
    comment: ?String,
    requires: Requires,
    command: telegram.Command,
    subdevice_address: ?i32,
    physical_memory_address: ?i32,
    logical_memory_address: ?i32,
    data: HexBinary,
    data_length: ?i32,
    expected_wkc: ?i32,
    retries: ?i32,
    validation: ?Validation,

    const Requires = enum {
        frame,
        cycle,
    };

    const Validation = struct {
        data: HexBinary,
        data_mask: ?HexBinary,
        timeout_ms: i32,
    };
};

const Name = struct {
    str: String,
    language_code_id: ?i32,
};

const ProcessImage = struct {
    inputs: ?Image,
    outputs: ?Image,

    const Image = struct {
        byte_size: i32,
        variables: []Variable,

        const Variable = struct {
            name: String,
            comment: ?String,
            data_type: ?String,
            bit_size: i32,
            bit_offset: i32,
        };
    };
};

const Cyclic = struct {
    comment: ?String,
    cycle_time_us: ?i32,
    priority: ?i32,
    task_id: ?String,
    // min length 1
    frame: []Frame,

    const Frame = struct {
        comment: ?String,
        // min length 1
        command: []FrameCommand,

        const FrameCommand = struct {
            // max len 4
            state: []MainDeviceState,
            comment: ?String,
            command: telegram.Command,
            subdevice_address: ?i32,
            physical_memory_address: ?i32,
            logical_memory_address: ?i32,
            data: ?HexBinary,
            data_length: ?i32,
            expected_wkc: ?i32,
            input_offset_bytes: ?i32,
            output_offset_bytes: ?i32,
            copy_info: ?CopyInfos,

            const MainDeviceState = enum {
                INIT,
                PREOP,
                SAFEOP,
                OP,
            };

            const CopyInfos = struct {
                copy_infos: []CopyInfo,
                const CopyInfo = struct {
                    source_bit_offset: HexDecValue,
                    destination_bit_offset: HexDecValue,
                    bit_size: HexDecValue,
                };
            };
        };
    };
};

const SubDevice = struct {
    info: Info,
    process_data: ?ProcessData,
    mailbox: ?Mailbox,
    init_cmds: ?InitECatCmds,
    previous_port: ?PreviousPort,
    hot_connect: ?HotConnect,
    dc: ?DC,

    const Info = struct {
        name: String,
        physical_address: ?i32,
        auto_increment_address: ?i32,
        physics: String,
        vendor_id: i32,
        product_code: i32,
        revision_number: i32,
        serial_number: i32,
        product_revision: ?i32,
    };

    const ProcessData = struct {
        send: ?Send,
        recv: ?Recv,
        sm0: ?SyncManagerSettings,
        sm1: ?SyncManagerSettings,
        sm2: ?SyncManagerSettings,
        sm3: ?SyncManagerSettings,
        tx_pdos: []PDO,
        rx_pdos: []PDO,

        const Recv = struct {
            bit_start: i32,
            bit_length: i32,
        };

        const Send = struct {
            bit_start: i32,
            bit_length: i32,
        };

        const SyncManagerSettings = struct {
            _type: SyncManagerType,
            min_size_bytes: ?i32,
            max_size_bytes: ?i32,
            default_size_bytes: ?i32,
            start_address: i32,
            control_byte: i32,
            enable: bool,
            virtual: ?bool,
            pdos: []i32,

            const SyncManagerType = enum {
                inputs,
                outputs,
            };
        };

        const PDO = struct {
            index: HexDecValue,
            // min len 1
            names: []Name,
            exclude: []HexDecValue,
            entries: []Entry,
            fixed: ?bool,
            mandatory: ?bool,
            virtual: ?bool,
            sync_manager: ?i32,
            sync_unit: ?i32,
            oversampling_factor_default: ?i32,
            oversampling_factor_min: ?i32,
            oversampling_factor_max: ?i32,
            oversampling_index_increment: ?i32,

            const Entry = struct {
                index: HexDecValue,
                subindex: ?HexDecValue,
                bit_length: i32,
                names: []Name,
                comment: ?String,
                data_type: ?String,
            };
        };
    };

    const PreviousPort = struct {
        selected: ?bool,
        device_id: ?i32,
        /// "A" "B" "C" or "D" (0,1,2,3)
        port: u2,
        physical_address: ?i32,
    };

    const HotConnect = struct {
        group_member_count: i32,
        /// min len = 1
        identify_command: []ECatCmd,
    };
    // TODO: fix DC
    const DC = struct {
        potential_reference_clock: bool,
    };

    const Mailbox = struct {
        data_link_later: ?bool,
        send: Send,
        recv: Recv,
        boostrap: ?Bootstrap,
        protocol: []Protocol,
        coe: CoE,
        soe: SoE,
        aoe: AoE,
        foe: FoE,
        voe: VoE,

        const Send = struct {
            start: i32,
            length_bytes: i32,
        };

        const Recv = struct {
            start: i32,
            length_bytes: i32,
            poll_time_ms: ?i32,
            status_bit_address: ?i32,
        };

        const Bootstrap = struct {
            send: Send,
            recv: Recv,
        };

        const Protocol = enum {
            AoE,
            EoE,
            CoE,
            SoE,
            FoE,
            VoE,
        };

        const MailboxCommand = struct {
            // min length 1
            //transitions: []Transition,
            comment: ?String,
            timeout_ms: i32,
            data: ?HexBinary,
            disabled: ?bool,
        };

        const InitMailboxCmds = struct {
            mailbox_cmds: []MailboxCommand,
        };
        const ServiceChannelCommand = struct {
            fixed: ?bool,
            // min length 1
            //transitions: []Transition,
            comment: ?String,
            timeout_ms: i32,
            op_code: i32,
            drive_number: i32,
            idn: i32,
            elements: i32,
            attribute: i32,
            data: ?HexBinary,
            disabled: ?bool,
        };
        const SoEInitMailboxCmds = struct {
            service_channel_commands: []ServiceChannelCommand,
        };
        const CoE = struct {
            init_cmds: ?CoEInitCmds,
            profile: ?Profile,
            const CoEInitCmds = struct {
                sdo_cmds: []SDOCommand,

                const SDOCommand = struct {
                    fixed: ?bool,
                    complete_access: ?bool,
                    // min len 1
                    //transitions: []Transition,
                    comment: ?String,
                    timeout_ms: i32,
                    ccs: CCS,
                    index: i32,
                    subindex: i32,
                    data: ?HexBinary,
                    disabled: ?bool,

                    const CCS = enum(u2) {
                        sdo_initiate_upload = 1,
                        sdo_initiate_download = 2,
                    };
                };
            };

            const Profile = struct {
                channel_infos: []ChannelInfo,
                vendor_specific: ?anyopaque,

                const ChannelInfo = struct {
                    overwritten_by_module: ?bool,
                    profile_number: String,
                    add_info: ?String,
                    display_name: []Name,
                };
            };
        };
        const SoE = struct {
            init_cmds: ?SoEInitMailboxCmds,
            net_id: ?String,
        };

        const AoE = struct {
            init_cmds: ?InitMailboxCmds,
            net_id: ?String,
        };
        const FoE = struct {
            init_cmds: ?InitMailboxCmds,
        };
        const VoE = struct {
            init_cmds: ?InitMailboxCmds,
        };
    };
};

const MainDevice = struct {
    info: Info,
    mailbox_states: ?MailboxStates,
    eoe: ?EoE,

    init_cmds: ?InitECatCmds,

    const Info = struct {
        name: String,
        destination: HexBinary,
        source: HexBinary,
        // TODO: allowed values of ethertype
        ether_type: ?EtherType,
    };

    const MailboxStates = struct {
        start_addr: i32,
        count: i32,
    };

    const EoE = struct {
        max_ports: i32,
        max_frames: i32,
        max_macs: i32,
    };
};

/// EtherCAT Network Information
pub const ENI = struct {
    main_device: MainDevice,
    subdevices: []SubDevice,
    cyclics: []Cyclic,
    process_image: ?ProcessImage,
};
