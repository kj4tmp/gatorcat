# Bus Info

```zon
.{
    .ifname = "enx00e04c68191a",
    .ring_position = null,
    .recv_timeout_us = 10000,
    .eeprom_timeout_us = 100000,
    .INIT_timeout_us = 5000000,
    .PREOP_timeout_us = 10000000,
    .mbx_timeout_us = 50000,
}
```
## Bus Summary

| Ring Pos.| Order ID| Auto-incr. Addr.| Station Addr.| Vendor ID| Product Code| Revision Number |
|---|---|---|---|---|---|---|
| 0     | EK1100           | 0x0000 | 0x1000 | 0x00000002 | 0x044c2c52 | 0x00110000 |
| 1     | EL7041-1000      | 0xffff | 0x1001 | 0x00000002 | 0x1b813052 | 0x001503e8 |

### Subdevice 0(0x1000): EK1100 

#### Addressing

| Property               | Value  |
|---                     |---     |
| Ring position          |     0  |
| Auto-increment address | 0x0000 |
| Station address        | 0x1000 |

#### Identity

| Property         | Value |
|---               |---    |
| Order ID         | EK1100 |
| Name             | EK1100 EtherCAT-Koppler (2A E-Bus) |
| Group            | SystemBk |
| Vendor ID        | 0x00000002 |
| Product code     | 0x044c2c52 |
| Revision number  | 0x00110000 |
| Serial number    | 0x00000000 |

#### SII Mailbox Info

Supported mailbox protocols: None




#### SII Catagory: General

| Property                               | Value |
|---                                     |---    |
| flags.enable_SAFEOP                    | false |
| flags.enable_not_LRW                   | false |
| flags.mailbox_data_link_layer          | false |
| flags.identity_AL_status_code          | false |
| flags.identity_physical_memory         | false |

#### SII Catagory: Sync Managers

No sync managers.



#### SII Catagory: TxPDOs

No TxPDOs catagory.

#### SII Catagory: RxPDOs

No RxPDOs catagory.

### Subdevice 1(0x1001): EL7041-1000 

#### Addressing

| Property               | Value  |
|---                     |---     |
| Ring position          |     1  |
| Auto-increment address | 0xffff |
| Station address        | 0x1001 |

#### Identity

| Property         | Value |
|---               |---    |
| Order ID         | EL7041-1000 |
| Name             | EL7041-1000 1K. Schrittmotor-Endstufe (50V, 5A, standard) |
| Group            | DriveAxisTerminals |
| Vendor ID        | 0x00000002 |
| Product code     | 0x1b813052 |
| Revision number  | 0x001503e8 |
| Serial number    | 0x00000000 |

#### SII Mailbox Info

Supported mailbox protocols: CoE FoE 

Default mailbox configuration:

    Mailbox out: offset: 0x1000 size: 128
    Mailbox in:  offset: 0x1080 size: 128

Bootstrap mailbox configuration:

    Mailbox out: offset: 0x1000 size: 244
    Mailbox in:  offset: 0x10f4 size: 244

#### SII Catagory: General

| Property                               | Value |
|---                                     |---    |
| coe_details.enable_SDO                 |  true |
| coe_details.enable_SDO_info            |  true |
| coe_details.enable_PDO_assign          |  true |
| coe_details.enable_PDO_configuration   | false |
| coe_details.enable_upload_at_startup   | false |
| coe_details.enable_SDO_complete_access |  true |
| foe_details.enable_foe                 |  true |
| flags.enable_SAFEOP                    | false |
| flags.enable_not_LRW                   | false |
| flags.mailbox_data_link_layer          |  true |
| flags.identity_AL_status_code          | false |
| flags.identity_physical_memory         | false |

#### SII Catagory: Sync Managers

##### SM0

    type: mailbox_out
    physical start addr: 0x1000
    length: 128
    control:
        buffer_type                 esc.SyncManagerBufferType.mailbox
        direction                   esc.SyncManagerDirection.output
        ECAT_event_enable           false
        DLS_user_event_enable       true 
        watchdog_enable             false
    status:
        channel_enable              false
        repeat                      false
        reserved3                   0    
        DC_event_0_bus_access       false
        DC_event_0_local_access     false
    enable:
        enable                      true 
        fixed_content               false
        virtual                     false
        OP_only                     false

##### SM1

    type: mailbox_in
    physical start addr: 0x1080
    length: 128
    control:
        buffer_type                 esc.SyncManagerBufferType.mailbox
        direction                   esc.SyncManagerDirection.input
        ECAT_event_enable           false
        DLS_user_event_enable       true 
        watchdog_enable             false
    status:
        channel_enable              false
        repeat                      false
        reserved3                   0    
        DC_event_0_bus_access       false
        DC_event_0_local_access     false
    enable:
        enable                      true 
        fixed_content               false
        virtual                     false
        OP_only                     false

##### SM2

    type: process_data_outputs
    physical start addr: 0x1100
    length: 8
    control:
        buffer_type                 esc.SyncManagerBufferType.buffered
        direction                   esc.SyncManagerDirection.output
        ECAT_event_enable           false
        DLS_user_event_enable       true 
        watchdog_enable             false
    status:
        channel_enable              false
        repeat                      false
        reserved3                   0    
        DC_event_0_bus_access       false
        DC_event_0_local_access     false
    enable:
        enable                      true 
        fixed_content               false
        virtual                     false
        OP_only                     false

##### SM3

    type: process_data_inputs
    physical start addr: 0x1180
    length: 8
    control:
        buffer_type                 esc.SyncManagerBufferType.buffered
        direction                   esc.SyncManagerDirection.input
        ECAT_event_enable           false
        DLS_user_event_enable       true 
        watchdog_enable             false
    status:
        channel_enable              false
        repeat                      false
        reserved3                   0    
        DC_event_0_bus_access       false
        DC_event_0_local_access     false
    enable:
        enable                      true 
        fixed_content               false
        virtual                     false
        OP_only                     false



#### SII Catagory: TxPDOs

    Inputs bit length: 64   
| PDO Index| SM| Mapped Index| Bits| Type| Name |
|---|---|---|---|---|---|
| 0x1a00 |   3 |           |  48 |                  | ENC Status compact         |
|        |     | 0x6000:01 |   1 | BOOLEAN          | Status__Latch C valid      |
|        |     | 0x6000:02 |   1 | BOOLEAN          | Status__Latch extern valid |
|        |     | 0x6000:03 |   1 | BOOLEAN          | Status__Set counter done   |
|        |     | 0x6000:04 |   1 | BOOLEAN          | Status__Counter underflow  |
|        |     | 0x6000:05 |   1 | BOOLEAN          | Status__Counter overflow   |
|        |     | 0x0000:00 |   2 | UNKNOWN          | Status__                   |
|        |     | 0x6000:08 |   1 | BOOLEAN          | Status__Extrapolation stall |
|        |     | 0x6000:09 |   1 | BOOLEAN          | Status__Status of input A  |
|        |     | 0x6000:0a |   1 | BOOLEAN          | Status__Status of input B  |
|        |     | 0x6000:0b |   1 | BOOLEAN          | Status__Status of input C  |
|        |     | 0x0000:00 |   1 | UNKNOWN          | Status__                   |
|        |     | 0x6000:0d |   1 | BOOLEAN          | Status__Status of extern latch |
|        |     | 0x6000:0e |   1 | BOOLEAN          | Status__Sync error         |
|        |     | 0x0000:00 |   1 | UNKNOWN          | Status__                   |
|        |     | 0x6000:10 |   1 | BOOLEAN          | Status__TxPDO Toggle       |
|        |     | 0x6000:11 |  16 | UNSIGNED16       | Counter value              |
|        |     | 0x6000:12 |  16 | UNSIGNED16       | Latch value                |
| 0x1a01 | 255 |           |  80 |                  | ENC Status                 |
|        |     | 0x6000:01 |   1 | BOOLEAN          | Status__Latch C valid      |
|        |     | 0x6000:02 |   1 | BOOLEAN          | Status__Latch extern valid |
|        |     | 0x6000:03 |   1 | BOOLEAN          | Status__Set counter done   |
|        |     | 0x6000:04 |   1 | BOOLEAN          | Status__Counter underflow  |
|        |     | 0x6000:05 |   1 | BOOLEAN          | Status__Counter overflow   |
|        |     | 0x0000:00 |   2 | UNKNOWN          | Status__                   |
|        |     | 0x6000:08 |   1 | BOOLEAN          | Status__Extrapolation stall |
|        |     | 0x6000:09 |   1 | BOOLEAN          | Status__Status of input A  |
|        |     | 0x6000:0a |   1 | BOOLEAN          | Status__Status of input B  |
|        |     | 0x6000:0b |   1 | BOOLEAN          | Status__Status of input C  |
|        |     | 0x0000:00 |   1 | UNKNOWN          | Status__                   |
|        |     | 0x6000:0d |   1 | BOOLEAN          | Status__Status of extern latch |
|        |     | 0x6000:0e |   1 | BOOLEAN          | Status__Sync error         |
|        |     | 0x0000:00 |   1 | UNKNOWN          | Status__                   |
|        |     | 0x6000:10 |   1 | BOOLEAN          | Status__TxPDO Toggle       |
|        |     | 0x6000:11 |  32 | UNSIGNED32       | Counter value              |
|        |     | 0x6000:12 |  32 | UNSIGNED32       | Latch value                |
| 0x1a02 | 255 |           |  32 |                  | ENC Timest. compact        |
|        |     | 0x6000:16 |  32 | UNSIGNED32       | Timestamp                  |
| 0x1a03 |   3 |           |  16 |                  | STM Status                 |
|        |     | 0x6010:01 |   1 | BOOLEAN          | Status__Ready to enable    |
|        |     | 0x6010:02 |   1 | BOOLEAN          | Status__Ready              |
|        |     | 0x6010:03 |   1 | BOOLEAN          | Status__Warning            |
|        |     | 0x6010:04 |   1 | BOOLEAN          | Status__Error              |
|        |     | 0x6010:05 |   1 | BOOLEAN          | Status__Moving positive    |
|        |     | 0x6010:06 |   1 | BOOLEAN          | Status__Moving negative    |
|        |     | 0x6010:07 |   1 | BOOLEAN          | Status__Torque reduced     |
|        |     | 0x0000:00 |   4 | UNKNOWN          | Status__                   |
|        |     | 0x6010:0c |   1 | BOOLEAN          | Status__Digital input 1    |
|        |     | 0x6010:0d |   1 | BOOLEAN          | Status__Digital input 2    |
|        |     | 0x6010:0e |   1 | BOOLEAN          | Status__Sync error         |
|        |     | 0x0000:00 |   1 | UNKNOWN          | Status__                   |
|        |     | 0x6010:10 |   1 | BOOLEAN          | Status__TxPDO Toggle       |

#### SII Catagory: RxPDOs

    Outputs bit length: 64   
| PDO Index| SM| Mapped Index| Bits| Type| Name |
|---|---|---|---|---|---|
| 0x1600 |   2 |           |  32 |                  | ENC Control compact        |
|        |     | 0x7000:01 |   1 | BOOLEAN          | Control__Enable latch C    |
|        |     | 0x7000:02 |   1 | BOOLEAN          | Control__Enable latch extern on positive edge |
|        |     | 0x7000:03 |   1 | BOOLEAN          | Control__Set counter       |
|        |     | 0x7000:04 |   1 | BOOLEAN          | Control__Enable latch extern on negative edge |
|        |     | 0x0000:00 |   4 | UNKNOWN          | Control__                  |
|        |     | 0x0000:00 |   8 | UNKNOWN          | Control__                  |
|        |     | 0x7000:11 |  16 | UNSIGNED16       | Set counter value          |
| 0x1601 | 255 |           |  48 |                  | ENC Control                |
|        |     | 0x7000:01 |   1 | BOOLEAN          | Control__Enable latch C    |
|        |     | 0x7000:02 |   1 | BOOLEAN          | Control__Enable latch extern on positive edge |
|        |     | 0x7000:03 |   1 | BOOLEAN          | Control__Set counter       |
|        |     | 0x7000:04 |   1 | BOOLEAN          | Control__Enable latch extern on negative edge |
|        |     | 0x0000:00 |   4 | UNKNOWN          | Control__                  |
|        |     | 0x0000:00 |   8 | UNKNOWN          | Control__                  |
|        |     | 0x7000:11 |  32 | UNSIGNED32       | Set counter value          |
| 0x1602 |   2 |           |  16 |                  | STM Control                |
|        |     | 0x7010:01 |   1 | BOOLEAN          | Control__Enable            |
|        |     | 0x7010:02 |   1 | BOOLEAN          | Control__Reset             |
|        |     | 0x7010:03 |   1 | BOOLEAN          | Control__Reduce torque     |
|        |     | 0x0000:00 |   5 | UNKNOWN          | Control__                  |
|        |     | 0x0000:00 |   8 | UNKNOWN          | Control__                  |
| 0x1603 | 255 |           |  32 |                  | STM Position               |
|        |     | 0x7010:11 |  32 | UNSIGNED32       | Position                   |
| 0x1604 |   2 |           |  16 |                  | STM Velocity               |
|        |     | 0x7010:21 |  16 | INTEGER16        | Velocity                   |

#### CoE: Sync Manager Communication Types

| SM  | Purpose          |
|---  |---               |
| 0   | mailbox_out      |
| 1   | mailbox_in       |
| 2   | output           |
| 3   | input            |

#### CoE: PDO Assignment

| PDO Index| SM| Mapped Index| Bits| Type| Name |
|---|---|---|---|---|---|
| 0x1600 |   2 |           |  32 |         | |
|        |     | 0x7000:01 |   1 |         | |
|        |     | 0x7000:02 |   1 |         | |
|        |     | 0x7000:03 |   1 |         | |
|        |     | 0x7000:04 |   1 |         | |
|        |     |           |   4 | PADDING | |
|        |     |           |   8 | PADDING | |
|        |     | 0x7000:11 |  16 |         | |
| 0x1602 |   2 |           |  16 |         | |
|        |     | 0x7010:01 |   1 |         | |
|        |     | 0x7010:02 |   1 |         | |
|        |     | 0x7010:03 |   1 |         | |
|        |     |           |   5 | PADDING | |
|        |     |           |   8 | PADDING | |
| 0x1604 |   2 |           |  16 |         | |
|        |     | 0x7010:21 |  16 |         | |
| 0x1a00 |   3 |           |  48 |         | |
|        |     | 0x6000:01 |   1 |         | |
|        |     | 0x6000:02 |   1 |         | |
|        |     | 0x6000:03 |   1 |         | |
|        |     | 0x6000:04 |   1 |         | |
|        |     | 0x6000:05 |   1 |         | |
|        |     |           |   2 | PADDING | |
|        |     | 0x6000:08 |   1 |         | |
|        |     | 0x6000:09 |   1 |         | |
|        |     | 0x6000:0a |   1 |         | |
|        |     | 0x6000:0b |   1 |         | |
|        |     |           |   1 | PADDING | |
|        |     | 0x6000:0d |   1 |         | |
|        |     | 0x6000:0e |   1 |         | |
|        |     |           |   1 | PADDING | |
|        |     | 0x6000:10 |   1 |         | |
|        |     | 0x6000:11 |  16 |         | |
|        |     | 0x6000:12 |  16 |         | |
| 0x1a03 |   3 |           |  16 |         | |
|        |     | 0x6010:01 |   1 |         | |
|        |     | 0x6010:02 |   1 |         | |
|        |     | 0x6010:03 |   1 |         | |
|        |     | 0x6010:04 |   1 |         | |
|        |     | 0x6010:05 |   1 |         | |
|        |     | 0x6010:06 |   1 |         | |
|        |     | 0x6010:07 |   1 |         | |
|        |     |           |   4 | PADDING | |
|        |     | 0x6010:0c |   1 |         | |
|        |     | 0x6010:0d |   1 |         | |
|        |     | 0x6010:0e |   1 |         | |
|        |     |           |   1 | PADDING | |
|        |     | 0x6010:10 |   1 |         | |


#### CoE: Object Description Lists

| List                             | Length |
|---                               |---     |
| all_objects                      |     44 |
| rx_pdo_mappable                  |      2 |
| tx_pdo_mappable                  |      2 |
| stored_for_device_replacement    |      4 |
| startup_parameters               |      4 |

#### CoE: Object Description List: All Objects

| Index| Max Subindex / Subindex| Name| Type |
|---|---|---|---|
| 0x1000    | 00 | Device type                                      | UNSIGNED32       |     |
| 0x1008    | 00 | Device name                                      | VISIBLE_STRING   |     |
| 0x1009    | 00 | Hardware version                                 | VISIBLE_STRING   |     |
| 0x100a    | 00 | Software version                                 | VISIBLE_STRING   |     |
| 0x1011    | 01 | Restore default parameters                       | UNSIGNED32       |     |
|           | 01 | SubIndex 001                                     | UNSIGNED32       | 32  |
| 0x1018    | 04 | Identity                                         | IDENTITY         |     |
|           | 01 | Vendor ID                                        | UNSIGNED32       | 32  |
|           | 02 | Product code                                     | UNSIGNED32       | 32  |
|           | 03 | Revision                                         | UNSIGNED32       | 32  |
|           | 04 | Serial number                                    | UNSIGNED32       | 32  |
| 0x10f0    | 01 | Backup parameter handling                        | INVALID          |     |
|           | 01 | Checksum                                         | UNSIGNED32       | 32  |
| 0x1400    | 06 | ENC RxPDO-Par Control compact                    | INVALID          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 0   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | Exclude RxPDOs                                   | OCTET_STRING     | 48  |
| 0x1401    | 06 | ENC RxPDO-Par Control                            | INVALID          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 0   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | Exclude RxPDOs                                   | OCTET_STRING     | 48  |
| 0x1403    | 06 | STM RxPDO-Par Position                           | INVALID          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 0   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | Exclude RxPDOs                                   | OCTET_STRING     | 48  |
| 0x1404    | 06 | STM RxPDO-Par Velocity                           | INVALID          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 0   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | Exclude RxPDOs                                   | OCTET_STRING     | 48  |
| 0x1600    | 07 | ENC RxPDO-Map Control compact                    | PDO_MAPPING      |     |
|           | 01 | SubIndex 001                                     | UNSIGNED32       | 32  |
|           | 02 | SubIndex 002                                     | UNSIGNED32       | 32  |
|           | 03 | SubIndex 003                                     | UNSIGNED32       | 32  |
|           | 04 | SubIndex 004                                     | UNSIGNED32       | 32  |
|           | 05 | SubIndex 005                                     | UNSIGNED32       | 32  |
|           | 06 | SubIndex 006                                     | UNSIGNED32       | 32  |
|           | 07 | SubIndex 007                                     | UNSIGNED32       | 32  |
| 0x1601    | 07 | ENC RxPDO-Map Control                            | PDO_MAPPING      |     |
|           | 01 | SubIndex 001                                     | UNSIGNED32       | 32  |
|           | 02 | SubIndex 002                                     | UNSIGNED32       | 32  |
|           | 03 | SubIndex 003                                     | UNSIGNED32       | 32  |
|           | 04 | SubIndex 004                                     | UNSIGNED32       | 32  |
|           | 05 | SubIndex 005                                     | UNSIGNED32       | 32  |
|           | 06 | SubIndex 006                                     | UNSIGNED32       | 32  |
|           | 07 | SubIndex 007                                     | UNSIGNED32       | 32  |
| 0x1602    | 05 | STM RxPDO-Map Control                            | PDO_MAPPING      |     |
|           | 01 | SubIndex 001                                     | UNSIGNED32       | 32  |
|           | 02 | SubIndex 002                                     | UNSIGNED32       | 32  |
|           | 03 | SubIndex 003                                     | UNSIGNED32       | 32  |
|           | 04 | SubIndex 004                                     | UNSIGNED32       | 32  |
|           | 05 | SubIndex 005                                     | UNSIGNED32       | 32  |
| 0x1603    | 01 | STM RxPDO-Map Position                           | PDO_MAPPING      |     |
|           | 01 | SubIndex 001                                     | UNSIGNED32       | 32  |
| 0x1604    | 01 | STM RxPDO-Map Velocity                           | PDO_MAPPING      |     |
|           | 01 | SubIndex 001                                     | UNSIGNED32       | 32  |
| 0x1800    | 06 | ENC TxPDO-Par Status compact                     | INVALID          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 0   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | Exclude TxPDOs                                   | OCTET_STRING     | 16  |
| 0x1801    | 06 | ENC TxPDO-Par Status                             | INVALID          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 0   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | Exclude TxPDOs                                   | OCTET_STRING     | 16  |
| 0x1a00    | 11 | ENC TxPDO-Map Status compact                     | PDO_MAPPING      |     |
|           | 01 | SubIndex 001                                     | UNSIGNED32       | 32  |
|           | 02 | SubIndex 002                                     | UNSIGNED32       | 32  |
|           | 03 | SubIndex 003                                     | UNSIGNED32       | 32  |
|           | 04 | SubIndex 004                                     | UNSIGNED32       | 32  |
|           | 05 | SubIndex 005                                     | UNSIGNED32       | 32  |
|           | 06 | SubIndex 006                                     | UNSIGNED32       | 32  |
|           | 07 | SubIndex 007                                     | UNSIGNED32       | 32  |
|           | 08 | SubIndex 008                                     | UNSIGNED32       | 32  |
|           | 09 | SubIndex 009                                     | UNSIGNED32       | 32  |
|           | 0a | SubIndex 010                                     | UNSIGNED32       | 32  |
|           | 0b | SubIndex 011                                     | UNSIGNED32       | 32  |
|           | 0c | SubIndex 012                                     | UNSIGNED32       | 32  |
|           | 0d | SubIndex 013                                     | UNSIGNED32       | 32  |
|           | 0e | SubIndex 014                                     | UNSIGNED32       | 32  |
|           | 0f | SubIndex 015                                     | UNSIGNED32       | 32  |
|           | 10 | SubIndex 016                                     | UNSIGNED32       | 32  |
|           | 11 | SubIndex 017                                     | UNSIGNED32       | 32  |
| 0x1a01    | 11 | ENC TxPDO-Map Status                             | PDO_MAPPING      |     |
|           | 01 | SubIndex 001                                     | UNSIGNED32       | 32  |
|           | 02 | SubIndex 002                                     | UNSIGNED32       | 32  |
|           | 03 | SubIndex 003                                     | UNSIGNED32       | 32  |
|           | 04 | SubIndex 004                                     | UNSIGNED32       | 32  |
|           | 05 | SubIndex 005                                     | UNSIGNED32       | 32  |
|           | 06 | SubIndex 006                                     | UNSIGNED32       | 32  |
|           | 07 | SubIndex 007                                     | UNSIGNED32       | 32  |
|           | 08 | SubIndex 008                                     | UNSIGNED32       | 32  |
|           | 09 | SubIndex 009                                     | UNSIGNED32       | 32  |
|           | 0a | SubIndex 010                                     | UNSIGNED32       | 32  |
|           | 0b | SubIndex 011                                     | UNSIGNED32       | 32  |
|           | 0c | SubIndex 012                                     | UNSIGNED32       | 32  |
|           | 0d | SubIndex 013                                     | UNSIGNED32       | 32  |
|           | 0e | SubIndex 014                                     | UNSIGNED32       | 32  |
|           | 0f | SubIndex 015                                     | UNSIGNED32       | 32  |
|           | 10 | SubIndex 016                                     | UNSIGNED32       | 32  |
|           | 11 | SubIndex 017                                     | UNSIGNED32       | 32  |
| 0x1a02    | 01 | ENC TxPDO-Map Timest. compact                    | PDO_MAPPING      |     |
|           | 01 | SubIndex 001                                     | UNSIGNED32       | 32  |
| 0x1a03    | 0d | STM TxPDO-Map Status                             | PDO_MAPPING      |     |
|           | 01 | SubIndex 001                                     | UNSIGNED32       | 32  |
|           | 02 | SubIndex 002                                     | UNSIGNED32       | 32  |
|           | 03 | SubIndex 003                                     | UNSIGNED32       | 32  |
|           | 04 | SubIndex 004                                     | UNSIGNED32       | 32  |
|           | 05 | SubIndex 005                                     | UNSIGNED32       | 32  |
|           | 06 | SubIndex 006                                     | UNSIGNED32       | 32  |
|           | 07 | SubIndex 007                                     | UNSIGNED32       | 32  |
|           | 08 | SubIndex 008                                     | UNSIGNED32       | 32  |
|           | 09 | SubIndex 009                                     | UNSIGNED32       | 32  |
|           | 0a | SubIndex 010                                     | UNSIGNED32       | 32  |
|           | 0b | SubIndex 011                                     | UNSIGNED32       | 32  |
|           | 0c | SubIndex 012                                     | UNSIGNED32       | 32  |
|           | 0d | SubIndex 013                                     | UNSIGNED32       | 32  |
| 0x1c00    | 04 | Sync manager type                                | UNSIGNED8        |     |
|           | 01 | SubIndex 001                                     | UNSIGNED8        | 8   |
|           | 02 | SubIndex 002                                     | UNSIGNED8        | 8   |
|           | 03 | SubIndex 003                                     | UNSIGNED8        | 8   |
|           | 04 | SubIndex 004                                     | UNSIGNED8        | 8   |
| 0x1c12    | 03 | RxPDO assign                                     | UNSIGNED16       |     |
|           | 01 | SubIndex 001                                     | UNSIGNED16       | 16  |
|           | 02 | SubIndex 002                                     | UNSIGNED16       | 16  |
|           | 03 | SubIndex 003                                     | UNSIGNED16       | 16  |
| 0x1c13    | 03 | TxPDO assign                                     | UNSIGNED16       |     |
|           | 01 | SubIndex 001                                     | UNSIGNED16       | 16  |
|           | 02 | SubIndex 002                                     | UNSIGNED16       | 16  |
|           | 03 | SubIndex 003                                     | UNSIGNED16       | 16  |
| 0x1c32    | 20 | SM output parameter                              | SYNC_PAR         |     |
|           | 01 | Sync mode                                        | UNSIGNED16       | 16  |
|           | 02 | Cycle time                                       | UNSIGNED32       | 32  |
|           | 03 | Shift time                                       | UNSIGNED32       | 32  |
|           | 04 | Sync modes supported                             | UNSIGNED16       | 16  |
|           | 05 | Minimum cycle time                               | UNSIGNED32       | 32  |
|           | 06 | Calc and copy time                               | UNSIGNED32       | 32  |
|           | 07 | Minimum delay time                               | UNSIGNED32       | 32  |
|           | 08 | Command                                          | UNSIGNED16       | 16  |
|           | 09 | Maximum delay time                               | UNSIGNED32       | 32  |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 32  |
|           | 0b | SM event missed counter                          | UNSIGNED16       | 16  |
|           | 0c | Cycle exceeded counter                           | UNSIGNED16       | 16  |
|           | 0d | Shift too short counter                          | UNSIGNED16       | 16  |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 16  |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 0   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | SubIndex 017                                     | UNKNOWN          | 0   |
|           | 12 | SubIndex 018                                     | UNKNOWN          | 0   |
|           | 13 | SubIndex 019                                     | UNKNOWN          | 0   |
|           | 14 | SubIndex 020                                     | UNKNOWN          | 0   |
|           | 15 | SubIndex 021                                     | UNKNOWN          | 0   |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | SubIndex 023                                     | UNKNOWN          | 0   |
|           | 18 | SubIndex 024                                     | UNKNOWN          | 0   |
|           | 19 | SubIndex 025                                     | UNKNOWN          | 0   |
|           | 1a | SubIndex 026                                     | UNKNOWN          | 0   |
|           | 1b | SubIndex 027                                     | UNKNOWN          | 0   |
|           | 1c | SubIndex 028                                     | UNKNOWN          | 0   |
|           | 1d | SubIndex 029                                     | UNKNOWN          | 0   |
|           | 1e | SubIndex 030                                     | UNKNOWN          | 0   |
|           | 1f | SubIndex 031                                     | UNKNOWN          | 0   |
|           | 20 | Sync error                                       | BOOLEAN          | 1   |
| 0x1c33    | 20 | SM input parameter                               | SYNC_PAR         |     |
|           | 01 | Sync mode                                        | UNSIGNED16       | 16  |
|           | 02 | Cycle time                                       | UNSIGNED32       | 32  |
|           | 03 | Shift time                                       | UNSIGNED32       | 32  |
|           | 04 | Sync modes supported                             | UNSIGNED16       | 16  |
|           | 05 | Minimum cycle time                               | UNSIGNED32       | 32  |
|           | 06 | Calc and copy time                               | UNSIGNED32       | 32  |
|           | 07 | Minimum delay time                               | UNSIGNED32       | 32  |
|           | 08 | Command                                          | UNSIGNED16       | 16  |
|           | 09 | Maximum delay time                               | UNSIGNED32       | 32  |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 32  |
|           | 0b | SM event missed counter                          | UNSIGNED16       | 16  |
|           | 0c | Cycle exceeded counter                           | UNSIGNED16       | 16  |
|           | 0d | Shift too short counter                          | UNSIGNED16       | 16  |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 16  |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 0   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | SubIndex 017                                     | UNKNOWN          | 0   |
|           | 12 | SubIndex 018                                     | UNKNOWN          | 0   |
|           | 13 | SubIndex 019                                     | UNKNOWN          | 0   |
|           | 14 | SubIndex 020                                     | UNKNOWN          | 0   |
|           | 15 | SubIndex 021                                     | UNKNOWN          | 0   |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | SubIndex 023                                     | UNKNOWN          | 0   |
|           | 18 | SubIndex 024                                     | UNKNOWN          | 0   |
|           | 19 | SubIndex 025                                     | UNKNOWN          | 0   |
|           | 1a | SubIndex 026                                     | UNKNOWN          | 0   |
|           | 1b | SubIndex 027                                     | UNKNOWN          | 0   |
|           | 1c | SubIndex 028                                     | UNKNOWN          | 0   |
|           | 1d | SubIndex 029                                     | UNKNOWN          | 0   |
|           | 1e | SubIndex 030                                     | UNKNOWN          | 0   |
|           | 1f | SubIndex 031                                     | UNKNOWN          | 0   |
|           | 20 | Sync error                                       | BOOLEAN          | 1   |
| 0x6000    | 16 | ENC Inputs Ch.1                                  | UNKNOWN          |     |
|           | 01 | Latch C valid                                    | BOOLEAN          | 1   |
|           | 02 | Latch extern valid                               | BOOLEAN          | 1   |
|           | 03 | Set counter done                                 | BOOLEAN          | 1   |
|           | 04 | Counter underflow                                | BOOLEAN          | 1   |
|           | 05 | Counter overflow                                 | BOOLEAN          | 1   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 1   |
|           | 07 | SubIndex 007                                     | UNKNOWN          | 1   |
|           | 08 | Extrapolation stall                              | BOOLEAN          | 1   |
|           | 09 | Status of input A                                | BOOLEAN          | 1   |
|           | 0a | Status of input B                                | BOOLEAN          | 1   |
|           | 0b | Status of input C                                | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 1   |
|           | 0d | Status of extern latch                           | BOOLEAN          | 1   |
|           | 0e | Sync error                                       | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 1   |
|           | 10 | TxPDO Toggle                                     | BOOLEAN          | 1   |
|           | 11 | Counter value                                    | UNSIGNED32       | 32  |
|           | 12 | Latch value                                      | UNSIGNED32       | 32  |
|           | 13 | SubIndex 019                                     | UNKNOWN          | 32  |
|           | 14 | SubIndex 020                                     | UNKNOWN          | 32  |
|           | 15 | SubIndex 021                                     | UNKNOWN          | 0   |
|           | 16 | Timestamp                                        | UNSIGNED32       | 32  |
| 0x6010    | 12 | STM Inputs Ch.1                                  | UNKNOWN          |     |
|           | 01 | Ready to enable                                  | BOOLEAN          | 1   |
|           | 02 | Ready                                            | BOOLEAN          | 1   |
|           | 03 | Warning                                          | BOOLEAN          | 1   |
|           | 04 | Error                                            | BOOLEAN          | 1   |
|           | 05 | Moving positive                                  | BOOLEAN          | 1   |
|           | 06 | Moving negative                                  | BOOLEAN          | 1   |
|           | 07 | Torque reduced                                   | BOOLEAN          | 1   |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 3   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | Digital input 1                                  | BOOLEAN          | 1   |
|           | 0d | Digital input 2                                  | BOOLEAN          | 1   |
|           | 0e | Sync error                                       | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 1   |
|           | 10 | TxPDO Toggle                                     | BOOLEAN          | 1   |
|           | 11 | SubIndex 017                                     | UNKNOWN          | 16  |
|           | 12 | SubIndex 018                                     | UNKNOWN          | 16  |
| 0x7000    | 11 | ENC Outputs Ch.1                                 | UNKNOWN          |     |
|           | 01 | Enable latch C                                   | BOOLEAN          | 1   |
|           | 02 | Enable latch extern on positive edge             | BOOLEAN          | 1   |
|           | 03 | Set counter                                      | BOOLEAN          | 1   |
|           | 04 | Enable latch extern on negative edge             | BOOLEAN          | 1   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 4   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 0   |
|           | 07 | SubIndex 007                                     | UNKNOWN          | 0   |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 0   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 8   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 0   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | Set counter value                                | UNSIGNED32       | 32  |
| 0x7010    | 21 | STM Outputs Ch.1                                 | UNKNOWN          |     |
|           | 01 | Enable                                           | BOOLEAN          | 1   |
|           | 02 | Reset                                            | BOOLEAN          | 1   |
|           | 03 | Reduce torque                                    | BOOLEAN          | 1   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 5   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 0   |
|           | 07 | SubIndex 007                                     | UNKNOWN          | 0   |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 0   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 3   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 1   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 1   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 3   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 0   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | Position                                         | UNSIGNED32       | 32  |
|           | 12 | SubIndex 018                                     | UNKNOWN          | 0   |
|           | 13 | SubIndex 019                                     | UNKNOWN          | 0   |
|           | 14 | SubIndex 020                                     | UNKNOWN          | 0   |
|           | 15 | SubIndex 021                                     | UNKNOWN          | 0   |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | SubIndex 023                                     | UNKNOWN          | 0   |
|           | 18 | SubIndex 024                                     | UNKNOWN          | 0   |
|           | 19 | SubIndex 025                                     | UNKNOWN          | 0   |
|           | 1a | SubIndex 026                                     | UNKNOWN          | 0   |
|           | 1b | SubIndex 027                                     | UNKNOWN          | 0   |
|           | 1c | SubIndex 028                                     | UNKNOWN          | 0   |
|           | 1d | SubIndex 029                                     | UNKNOWN          | 0   |
|           | 1e | SubIndex 030                                     | UNKNOWN          | 0   |
|           | 1f | SubIndex 031                                     | UNKNOWN          | 0   |
|           | 20 | SubIndex 032                                     | UNKNOWN          | 0   |
|           | 21 | Velocity                                         | INTEGER16        | 16  |
| 0x8000    | 12 | ENC Settings Ch.1                                | UNKNOWN          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 1   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 1   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 1   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 2   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 2   |
|           | 07 | SubIndex 007                                     | UNKNOWN          | 0   |
|           | 08 | Disable filter                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable micro increments                          | BOOLEAN          | 1   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 1   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 1   |
|           | 0e | Reversion of rotation                            | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 1   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 1   |
|           | 11 | SubIndex 017                                     | UNKNOWN          | 16  |
|           | 12 | SubIndex 018                                     | UNKNOWN          | 32  |
| 0x8010    | 11 | STM Motor Settings Ch.1                          | UNKNOWN          |     |
|           | 01 | Maximal current                                  | UNSIGNED16       | 16  |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 16  |
|           | 03 | Nominal voltage                                  | UNSIGNED16       | 16  |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 16  |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 16  |
|           | 06 | Motor fullsteps                                  | UNSIGNED16       | 16  |
|           | 07 | Encoder increments (4-fold)                      | UNSIGNED16       | 16  |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 16  |
|           | 09 | Start velocity                                   | UNSIGNED16       | 16  |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 0   |
|           | 10 | Drive on delay time                              | UNSIGNED16       | 16  |
|           | 11 | Drive off delay time                             | UNSIGNED16       | 16  |
| 0x8012    | 46 | STM Features Ch.1                                | UNKNOWN          |     |
|           | 01 | Operation mode                                   | INVALID          | 4   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 3   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 0   |
|           | 07 | SubIndex 007                                     | UNKNOWN          | 0   |
|           | 08 | Feedback type                                    | INVALID          | 1   |
|           | 09 | Invert motor polarity                            | BOOLEAN          | 1   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 7   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 0   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | SubIndex 017                                     | UNKNOWN          | 8   |
|           | 12 | SubIndex 018                                     | UNKNOWN          | 0   |
|           | 13 | SubIndex 019                                     | UNKNOWN          | 0   |
|           | 14 | SubIndex 020                                     | UNKNOWN          | 0   |
|           | 15 | SubIndex 021                                     | UNKNOWN          | 0   |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | SubIndex 023                                     | UNKNOWN          | 0   |
|           | 18 | SubIndex 024                                     | UNKNOWN          | 0   |
|           | 19 | SubIndex 025                                     | UNKNOWN          | 8   |
|           | 1a | SubIndex 026                                     | UNKNOWN          | 0   |
|           | 1b | SubIndex 027                                     | UNKNOWN          | 0   |
|           | 1c | SubIndex 028                                     | UNKNOWN          | 0   |
|           | 1d | SubIndex 029                                     | UNKNOWN          | 0   |
|           | 1e | SubIndex 030                                     | UNKNOWN          | 0   |
|           | 1f | SubIndex 031                                     | UNKNOWN          | 0   |
|           | 20 | SubIndex 032                                     | UNKNOWN          | 0   |
|           | 21 | SubIndex 033                                     | UNKNOWN          | 8   |
|           | 22 | SubIndex 034                                     | UNKNOWN          | 0   |
|           | 23 | SubIndex 035                                     | UNKNOWN          | 0   |
|           | 24 | SubIndex 036                                     | UNKNOWN          | 0   |
|           | 25 | SubIndex 037                                     | UNKNOWN          | 0   |
|           | 26 | SubIndex 038                                     | UNKNOWN          | 0   |
|           | 27 | SubIndex 039                                     | UNKNOWN          | 0   |
|           | 28 | SubIndex 040                                     | UNKNOWN          | 0   |
|           | 29 | SubIndex 041                                     | UNKNOWN          | 7   |
|           | 2a | SubIndex 042                                     | UNKNOWN          | 0   |
|           | 2b | SubIndex 043                                     | UNKNOWN          | 0   |
|           | 2c | SubIndex 044                                     | UNKNOWN          | 0   |
|           | 2d | SubIndex 045                                     | UNKNOWN          | 0   |
|           | 2e | SubIndex 046                                     | UNKNOWN          | 0   |
|           | 2f | SubIndex 047                                     | UNKNOWN          | 0   |
|           | 30 | Invert digital input 1                           | BOOLEAN          | 1   |
|           | 31 | Invert digital input 2                           | BOOLEAN          | 1   |
|           | 32 | Function for input 1                             | INVALID          | 4   |
|           | 33 | SubIndex 051                                     | UNKNOWN          | 0   |
|           | 34 | SubIndex 052                                     | UNKNOWN          | 0   |
|           | 35 | SubIndex 053                                     | UNKNOWN          | 0   |
|           | 36 | Function for input 2                             | INVALID          | 4   |
|           | 37 | SubIndex 055                                     | UNKNOWN          | 0   |
|           | 38 | SubIndex 056                                     | UNKNOWN          | 0   |
|           | 39 | SubIndex 057                                     | UNKNOWN          | 0   |
|           | 3a | SubIndex 058                                     | UNKNOWN          | 4   |
|           | 3b | SubIndex 059                                     | UNKNOWN          | 0   |
|           | 3c | SubIndex 060                                     | UNKNOWN          | 0   |
|           | 3d | SubIndex 061                                     | UNKNOWN          | 0   |
|           | 3e | SubIndex 062                                     | UNKNOWN          | 3   |
|           | 3f | SubIndex 063                                     | UNKNOWN          | 0   |
|           | 40 | SubIndex 064                                     | UNKNOWN          | 0   |
|           | 41 | SubIndex 065                                     | UNKNOWN          | 4   |
|           | 42 | SubIndex 066                                     | UNKNOWN          | 0   |
|           | 43 | SubIndex 067                                     | UNKNOWN          | 0   |
|           | 44 | SubIndex 068                                     | UNKNOWN          | 0   |
|           | 45 | Microstepping                                    | INVALID          | 4   |
|           | 46 | SubIndex 070                                     | UNKNOWN          | 8   |
| 0x8014    | 06 | STM Motor Settings 2 Ch.1                        | UNKNOWN          |     |
|           | 01 | Acceleration (maximum)                           | UNSIGNED16       | 16  |
|           | 02 | Acceleration threshold                           | UNSIGNED16       | 16  |
|           | 03 | Coil current (a>a,th)                            | UNSIGNED8        | 8   |
|           | 04 | Coil current (a<a,th)                            | UNSIGNED8        | 8   |
|           | 05 | Coil current (v=0, auto)                         | UNSIGNED8        | 8   |
|           | 06 | Coil current (v=0, manual)                       | UNSIGNED8        | 8   |
| 0x9010    | 08 | STM Info data Ch.1                               | UNKNOWN          |     |
|           | 01 | Status word                                      | UNSIGNED16       | 16  |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 16  |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 16  |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 16  |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 16  |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 8   |
|           | 07 | SubIndex 007                                     | UNKNOWN          | 8   |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 16  |
| 0xa010    | 13 | STM Diag data Ch.1                               | UNKNOWN          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 1   |
|           | 02 | Over temperature                                 | BOOLEAN          | 1   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 1   |
|           | 04 | Under voltage                                    | BOOLEAN          | 1   |
|           | 05 | Over voltage                                     | BOOLEAN          | 1   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 1   |
|           | 07 | SubIndex 007                                     | UNKNOWN          | 1   |
|           | 08 | No control power                                 | BOOLEAN          | 1   |
|           | 09 | Misc error                                       | BOOLEAN          | 1   |
|           | 0a | Open load A                                      | BOOLEAN          | 1   |
|           | 0b | Open load B                                      | BOOLEAN          | 1   |
|           | 0c | Over current A                                   | BOOLEAN          | 1   |
|           | 0d | Over current B                                   | BOOLEAN          | 1   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 3   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 0   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | Actual operation mode                            | INVALID          | 4   |
|           | 12 | SubIndex 018                                     | UNKNOWN          | 4   |
|           | 13 | SubIndex 019                                     | UNKNOWN          | 8   |
| 0xf000    | 02 | Modular device profile                           | INVALID          |     |
|           | 01 | Module index distance                            | UNSIGNED16       | 16  |
|           | 02 | Maximum number of modules                        | UNSIGNED16       | 16  |
| 0xf008    | 00 | Code word                                        | UNSIGNED32       |     |
| 0xf010    | 02 | Module list                                      | UNSIGNED32       |     |
|           | 01 | SubIndex 001                                     | UNSIGNED32       | 32  |
|           | 02 | SubIndex 002                                     | UNSIGNED32       | 32  |
| 0xf081    | 01 | Download revision                                | UNKNOWN          |     |
|           | 01 | Revision number                                  | UNSIGNED32       | 32  |
| 0xf80f    | 67 | STM Vendor data                                  | UNKNOWN          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 16  |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 16  |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 16  |
|           | 04 | Warning temperature                              | INTEGER8         | 8   |
|           | 05 | Switch off temperature                           | INTEGER8         | 8   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 16  |
|           | 07 | SubIndex 007                                     | UNKNOWN          | 16  |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 16  |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 0   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 0   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | SubIndex 017                                     | UNKNOWN          | 0   |
|           | 12 | SubIndex 018                                     | UNKNOWN          | 0   |
|           | 13 | SubIndex 019                                     | UNKNOWN          | 0   |
|           | 14 | SubIndex 020                                     | UNKNOWN          | 0   |
|           | 15 | SubIndex 021                                     | UNKNOWN          | 0   |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | SubIndex 023                                     | UNKNOWN          | 0   |
|           | 18 | SubIndex 024                                     | UNKNOWN          | 0   |
|           | 19 | SubIndex 025                                     | UNKNOWN          | 0   |
|           | 1a | SubIndex 026                                     | UNKNOWN          | 0   |
|           | 1b | SubIndex 027                                     | UNKNOWN          | 0   |
|           | 1c | SubIndex 028                                     | UNKNOWN          | 0   |
|           | 1d | SubIndex 029                                     | UNKNOWN          | 0   |
|           | 1e | SubIndex 030                                     | UNKNOWN          | 0   |
|           | 1f | SubIndex 031                                     | UNKNOWN          | 0   |
|           | 20 | SubIndex 032                                     | UNKNOWN          | 0   |
|           | 21 | SubIndex 033                                     | UNKNOWN          | 0   |
|           | 22 | SubIndex 034                                     | UNKNOWN          | 0   |
|           | 23 | SubIndex 035                                     | UNKNOWN          | 0   |
|           | 24 | SubIndex 036                                     | UNKNOWN          | 0   |
|           | 25 | SubIndex 037                                     | UNKNOWN          | 0   |
|           | 26 | SubIndex 038                                     | UNKNOWN          | 0   |
|           | 27 | SubIndex 039                                     | UNKNOWN          | 0   |
|           | 28 | SubIndex 040                                     | UNKNOWN          | 0   |
|           | 29 | SubIndex 041                                     | UNKNOWN          | 0   |
|           | 2a | SubIndex 042                                     | UNKNOWN          | 0   |
|           | 2b | SubIndex 043                                     | UNKNOWN          | 0   |
|           | 2c | SubIndex 044                                     | UNKNOWN          | 0   |
|           | 2d | SubIndex 045                                     | UNKNOWN          | 0   |
|           | 2e | SubIndex 046                                     | UNKNOWN          | 0   |
|           | 2f | SubIndex 047                                     | UNKNOWN          | 0   |
|           | 30 | SubIndex 048                                     | UNKNOWN          | 0   |
|           | 31 | SubIndex 049                                     | UNKNOWN          | 0   |
|           | 32 | SubIndex 050                                     | UNKNOWN          | 0   |
|           | 33 | SubIndex 051                                     | UNKNOWN          | 0   |
|           | 34 | SubIndex 052                                     | UNKNOWN          | 0   |
|           | 35 | SubIndex 053                                     | UNKNOWN          | 0   |
|           | 36 | SubIndex 054                                     | UNKNOWN          | 0   |
|           | 37 | SubIndex 055                                     | UNKNOWN          | 0   |
|           | 38 | SubIndex 056                                     | UNKNOWN          | 0   |
|           | 39 | SubIndex 057                                     | UNKNOWN          | 0   |
|           | 3a | SubIndex 058                                     | UNKNOWN          | 0   |
|           | 3b | SubIndex 059                                     | UNKNOWN          | 0   |
|           | 3c | SubIndex 060                                     | UNKNOWN          | 0   |
|           | 3d | SubIndex 061                                     | UNKNOWN          | 0   |
|           | 3e | SubIndex 062                                     | UNKNOWN          | 0   |
|           | 3f | SubIndex 063                                     | UNKNOWN          | 0   |
|           | 40 | SubIndex 064                                     | UNKNOWN          | 0   |
|           | 41 | SubIndex 065                                     | UNKNOWN          | 0   |
|           | 42 | SubIndex 066                                     | UNKNOWN          | 0   |
|           | 43 | SubIndex 067                                     | UNKNOWN          | 0   |
|           | 44 | SubIndex 068                                     | UNKNOWN          | 0   |
|           | 45 | SubIndex 069                                     | UNKNOWN          | 0   |
|           | 46 | SubIndex 070                                     | UNKNOWN          | 0   |
|           | 47 | SubIndex 071                                     | UNKNOWN          | 0   |
|           | 48 | SubIndex 072                                     | UNKNOWN          | 0   |
|           | 49 | SubIndex 073                                     | UNKNOWN          | 0   |
|           | 4a | SubIndex 074                                     | UNKNOWN          | 0   |
|           | 4b | SubIndex 075                                     | UNKNOWN          | 0   |
|           | 4c | SubIndex 076                                     | UNKNOWN          | 0   |
|           | 4d | SubIndex 077                                     | UNKNOWN          | 0   |
|           | 4e | SubIndex 078                                     | UNKNOWN          | 0   |
|           | 4f | SubIndex 079                                     | UNKNOWN          | 0   |
|           | 50 | SubIndex 080                                     | UNKNOWN          | 0   |
|           | 51 | SubIndex 081                                     | UNKNOWN          | 0   |
|           | 52 | SubIndex 082                                     | UNKNOWN          | 0   |
|           | 53 | SubIndex 083                                     | UNKNOWN          | 0   |
|           | 54 | SubIndex 084                                     | UNKNOWN          | 0   |
|           | 55 | SubIndex 085                                     | UNKNOWN          | 0   |
|           | 56 | SubIndex 086                                     | UNKNOWN          | 0   |
|           | 57 | SubIndex 087                                     | UNKNOWN          | 0   |
|           | 58 | SubIndex 088                                     | UNKNOWN          | 0   |
|           | 59 | SubIndex 089                                     | UNKNOWN          | 0   |
|           | 5a | SubIndex 090                                     | UNKNOWN          | 0   |
|           | 5b | SubIndex 091                                     | UNKNOWN          | 0   |
|           | 5c | SubIndex 092                                     | UNKNOWN          | 0   |
|           | 5d | SubIndex 093                                     | UNKNOWN          | 0   |
|           | 5e | SubIndex 094                                     | UNKNOWN          | 0   |
|           | 5f | SubIndex 095                                     | UNKNOWN          | 0   |
|           | 60 | SubIndex 096                                     | UNKNOWN          | 0   |
|           | 61 | SubIndex 097                                     | UNKNOWN          | 0   |
|           | 62 | SubIndex 098                                     | UNKNOWN          | 0   |
|           | 63 | SubIndex 099                                     | UNKNOWN          | 0   |
|           | 64 | Ramp divider                                     | UNSIGNED8        | 8   |
|           | 65 | Pulse divider                                    | UNSIGNED8        | 8   |
|           | 66 | Tolerance                                        | UNSIGNED8        | 8   |
|           | 67 | SubIndex 103                                     | UNKNOWN          | 8   |
| 0xf900    | 06 | STM Info data                                    | UNKNOWN          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 16  |
|           | 02 | Internal temperature                             | INTEGER8         | 8   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 8   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 16  |
|           | 05 | Motor supply voltage                             | UNSIGNED16       | 16  |
|           | 06 | Cycle time                                       | UNSIGNED16       | 16  |
| 0xfb00    | 04 | STM Command                                      | UNKNOWN          |     |
|           | 01 | Request                                          | OCTET_STRING     | 16  |
|           | 02 | Status                                           | UNSIGNED8        | 8   |
|           | 03 | Response                                         | OCTET_STRING     | 32  |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 8   |

#### CoE: Object Description List: RxPDO Mappable

| Index| Max Subindex / Subindex| Name| Type |
|---|---|---|---|
| 0x7000    | 11 | ENC Outputs Ch.1                                 | UNKNOWN          |     |
|           | 01 | Enable latch C                                   | BOOLEAN          | 1   |
|           | 02 | Enable latch extern on positive edge             | BOOLEAN          | 1   |
|           | 03 | Set counter                                      | BOOLEAN          | 1   |
|           | 04 | Enable latch extern on negative edge             | BOOLEAN          | 1   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 4   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 0   |
|           | 07 | SubIndex 007                                     | UNKNOWN          | 0   |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 0   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 8   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 0   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | Set counter value                                | UNSIGNED32       | 32  |
| 0x7010    | 21 | STM Outputs Ch.1                                 | UNKNOWN          |     |
|           | 01 | Enable                                           | BOOLEAN          | 1   |
|           | 02 | Reset                                            | BOOLEAN          | 1   |
|           | 03 | Reduce torque                                    | BOOLEAN          | 1   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 5   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 0   |
|           | 07 | SubIndex 007                                     | UNKNOWN          | 0   |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 0   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 3   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 1   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 1   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 3   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 0   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | Position                                         | UNSIGNED32       | 32  |
|           | 12 | SubIndex 018                                     | UNKNOWN          | 0   |
|           | 13 | SubIndex 019                                     | UNKNOWN          | 0   |
|           | 14 | SubIndex 020                                     | UNKNOWN          | 0   |
|           | 15 | SubIndex 021                                     | UNKNOWN          | 0   |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | SubIndex 023                                     | UNKNOWN          | 0   |
|           | 18 | SubIndex 024                                     | UNKNOWN          | 0   |
|           | 19 | SubIndex 025                                     | UNKNOWN          | 0   |
|           | 1a | SubIndex 026                                     | UNKNOWN          | 0   |
|           | 1b | SubIndex 027                                     | UNKNOWN          | 0   |
|           | 1c | SubIndex 028                                     | UNKNOWN          | 0   |
|           | 1d | SubIndex 029                                     | UNKNOWN          | 0   |
|           | 1e | SubIndex 030                                     | UNKNOWN          | 0   |
|           | 1f | SubIndex 031                                     | UNKNOWN          | 0   |
|           | 20 | SubIndex 032                                     | UNKNOWN          | 0   |
|           | 21 | Velocity                                         | INTEGER16        | 16  |

#### CoE: Object Description List: TxPDO Mappable

| Index| Max Subindex / Subindex| Name| Type |
|---|---|---|---|
| 0x6000    | 16 | ENC Inputs Ch.1                                  | UNKNOWN          |     |
|           | 01 | Latch C valid                                    | BOOLEAN          | 1   |
|           | 02 | Latch extern valid                               | BOOLEAN          | 1   |
|           | 03 | Set counter done                                 | BOOLEAN          | 1   |
|           | 04 | Counter underflow                                | BOOLEAN          | 1   |
|           | 05 | Counter overflow                                 | BOOLEAN          | 1   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 1   |
|           | 07 | SubIndex 007                                     | UNKNOWN          | 1   |
|           | 08 | Extrapolation stall                              | BOOLEAN          | 1   |
|           | 09 | Status of input A                                | BOOLEAN          | 1   |
|           | 0a | Status of input B                                | BOOLEAN          | 1   |
|           | 0b | Status of input C                                | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 1   |
|           | 0d | Status of extern latch                           | BOOLEAN          | 1   |
|           | 0e | Sync error                                       | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 1   |
|           | 10 | TxPDO Toggle                                     | BOOLEAN          | 1   |
|           | 11 | Counter value                                    | UNSIGNED32       | 32  |
|           | 12 | Latch value                                      | UNSIGNED32       | 32  |
|           | 13 | SubIndex 019                                     | UNKNOWN          | 32  |
|           | 14 | SubIndex 020                                     | UNKNOWN          | 32  |
|           | 15 | SubIndex 021                                     | UNKNOWN          | 0   |
|           | 16 | Timestamp                                        | UNSIGNED32       | 32  |
| 0x6010    | 12 | STM Inputs Ch.1                                  | UNKNOWN          |     |
|           | 01 | Ready to enable                                  | BOOLEAN          | 1   |
|           | 02 | Ready                                            | BOOLEAN          | 1   |
|           | 03 | Warning                                          | BOOLEAN          | 1   |
|           | 04 | Error                                            | BOOLEAN          | 1   |
|           | 05 | Moving positive                                  | BOOLEAN          | 1   |
|           | 06 | Moving negative                                  | BOOLEAN          | 1   |
|           | 07 | Torque reduced                                   | BOOLEAN          | 1   |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 3   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | Digital input 1                                  | BOOLEAN          | 1   |
|           | 0d | Digital input 2                                  | BOOLEAN          | 1   |
|           | 0e | Sync error                                       | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 1   |
|           | 10 | TxPDO Toggle                                     | BOOLEAN          | 1   |
|           | 11 | SubIndex 017                                     | UNKNOWN          | 16  |
|           | 12 | SubIndex 018                                     | UNKNOWN          | 16  |

#### CoE: Object Description List: Stored for Device Replacement

| Index| Max Subindex / Subindex| Name| Type |
|---|---|---|---|
| 0x8000    | 12 | ENC Settings Ch.1                                | UNKNOWN          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 1   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 1   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 1   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 2   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 2   |
|           | 07 | SubIndex 007                                     | UNKNOWN          | 0   |
|           | 08 | Disable filter                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable micro increments                          | BOOLEAN          | 1   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 1   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 1   |
|           | 0e | Reversion of rotation                            | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 1   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 1   |
|           | 11 | SubIndex 017                                     | UNKNOWN          | 16  |
|           | 12 | SubIndex 018                                     | UNKNOWN          | 32  |
| 0x8010    | 11 | STM Motor Settings Ch.1                          | UNKNOWN          |     |
|           | 01 | Maximal current                                  | UNSIGNED16       | 16  |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 16  |
|           | 03 | Nominal voltage                                  | UNSIGNED16       | 16  |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 16  |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 16  |
|           | 06 | Motor fullsteps                                  | UNSIGNED16       | 16  |
|           | 07 | Encoder increments (4-fold)                      | UNSIGNED16       | 16  |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 16  |
|           | 09 | Start velocity                                   | UNSIGNED16       | 16  |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 0   |
|           | 10 | Drive on delay time                              | UNSIGNED16       | 16  |
|           | 11 | Drive off delay time                             | UNSIGNED16       | 16  |
| 0x8012    | 46 | STM Features Ch.1                                | UNKNOWN          |     |
|           | 01 | Operation mode                                   | INVALID          | 4   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 3   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 0   |
|           | 07 | SubIndex 007                                     | UNKNOWN          | 0   |
|           | 08 | Feedback type                                    | INVALID          | 1   |
|           | 09 | Invert motor polarity                            | BOOLEAN          | 1   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 7   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 0   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | SubIndex 017                                     | UNKNOWN          | 8   |
|           | 12 | SubIndex 018                                     | UNKNOWN          | 0   |
|           | 13 | SubIndex 019                                     | UNKNOWN          | 0   |
|           | 14 | SubIndex 020                                     | UNKNOWN          | 0   |
|           | 15 | SubIndex 021                                     | UNKNOWN          | 0   |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | SubIndex 023                                     | UNKNOWN          | 0   |
|           | 18 | SubIndex 024                                     | UNKNOWN          | 0   |
|           | 19 | SubIndex 025                                     | UNKNOWN          | 8   |
|           | 1a | SubIndex 026                                     | UNKNOWN          | 0   |
|           | 1b | SubIndex 027                                     | UNKNOWN          | 0   |
|           | 1c | SubIndex 028                                     | UNKNOWN          | 0   |
|           | 1d | SubIndex 029                                     | UNKNOWN          | 0   |
|           | 1e | SubIndex 030                                     | UNKNOWN          | 0   |
|           | 1f | SubIndex 031                                     | UNKNOWN          | 0   |
|           | 20 | SubIndex 032                                     | UNKNOWN          | 0   |
|           | 21 | SubIndex 033                                     | UNKNOWN          | 8   |
|           | 22 | SubIndex 034                                     | UNKNOWN          | 0   |
|           | 23 | SubIndex 035                                     | UNKNOWN          | 0   |
|           | 24 | SubIndex 036                                     | UNKNOWN          | 0   |
|           | 25 | SubIndex 037                                     | UNKNOWN          | 0   |
|           | 26 | SubIndex 038                                     | UNKNOWN          | 0   |
|           | 27 | SubIndex 039                                     | UNKNOWN          | 0   |
|           | 28 | SubIndex 040                                     | UNKNOWN          | 0   |
|           | 29 | SubIndex 041                                     | UNKNOWN          | 7   |
|           | 2a | SubIndex 042                                     | UNKNOWN          | 0   |
|           | 2b | SubIndex 043                                     | UNKNOWN          | 0   |
|           | 2c | SubIndex 044                                     | UNKNOWN          | 0   |
|           | 2d | SubIndex 045                                     | UNKNOWN          | 0   |
|           | 2e | SubIndex 046                                     | UNKNOWN          | 0   |
|           | 2f | SubIndex 047                                     | UNKNOWN          | 0   |
|           | 30 | Invert digital input 1                           | BOOLEAN          | 1   |
|           | 31 | Invert digital input 2                           | BOOLEAN          | 1   |
|           | 32 | Function for input 1                             | INVALID          | 4   |
|           | 33 | SubIndex 051                                     | UNKNOWN          | 0   |
|           | 34 | SubIndex 052                                     | UNKNOWN          | 0   |
|           | 35 | SubIndex 053                                     | UNKNOWN          | 0   |
|           | 36 | Function for input 2                             | INVALID          | 4   |
|           | 37 | SubIndex 055                                     | UNKNOWN          | 0   |
|           | 38 | SubIndex 056                                     | UNKNOWN          | 0   |
|           | 39 | SubIndex 057                                     | UNKNOWN          | 0   |
|           | 3a | SubIndex 058                                     | UNKNOWN          | 4   |
|           | 3b | SubIndex 059                                     | UNKNOWN          | 0   |
|           | 3c | SubIndex 060                                     | UNKNOWN          | 0   |
|           | 3d | SubIndex 061                                     | UNKNOWN          | 0   |
|           | 3e | SubIndex 062                                     | UNKNOWN          | 3   |
|           | 3f | SubIndex 063                                     | UNKNOWN          | 0   |
|           | 40 | SubIndex 064                                     | UNKNOWN          | 0   |
|           | 41 | SubIndex 065                                     | UNKNOWN          | 4   |
|           | 42 | SubIndex 066                                     | UNKNOWN          | 0   |
|           | 43 | SubIndex 067                                     | UNKNOWN          | 0   |
|           | 44 | SubIndex 068                                     | UNKNOWN          | 0   |
|           | 45 | Microstepping                                    | INVALID          | 4   |
|           | 46 | SubIndex 070                                     | UNKNOWN          | 8   |
| 0x8014    | 06 | STM Motor Settings 2 Ch.1                        | UNKNOWN          |     |
|           | 01 | Acceleration (maximum)                           | UNSIGNED16       | 16  |
|           | 02 | Acceleration threshold                           | UNSIGNED16       | 16  |
|           | 03 | Coil current (a>a,th)                            | UNSIGNED8        | 8   |
|           | 04 | Coil current (a<a,th)                            | UNSIGNED8        | 8   |
|           | 05 | Coil current (v=0, auto)                         | UNSIGNED8        | 8   |
|           | 06 | Coil current (v=0, manual)                       | UNSIGNED8        | 8   |

#### CoE: Object Description List: Startup Parameters

| Index| Max Subindex / Subindex| Name| Type |
|---|---|---|---|
| 0x8000    | 12 | ENC Settings Ch.1                                | UNKNOWN          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 1   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 1   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 1   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 2   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 2   |
|           | 07 | SubIndex 007                                     | UNKNOWN          | 0   |
|           | 08 | Disable filter                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable micro increments                          | BOOLEAN          | 1   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 1   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 1   |
|           | 0e | Reversion of rotation                            | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 1   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 1   |
|           | 11 | SubIndex 017                                     | UNKNOWN          | 16  |
|           | 12 | SubIndex 018                                     | UNKNOWN          | 32  |
| 0x8010    | 11 | STM Motor Settings Ch.1                          | UNKNOWN          |     |
|           | 01 | Maximal current                                  | UNSIGNED16       | 16  |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 16  |
|           | 03 | Nominal voltage                                  | UNSIGNED16       | 16  |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 16  |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 16  |
|           | 06 | Motor fullsteps                                  | UNSIGNED16       | 16  |
|           | 07 | Encoder increments (4-fold)                      | UNSIGNED16       | 16  |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 16  |
|           | 09 | Start velocity                                   | UNSIGNED16       | 16  |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 0   |
|           | 10 | Drive on delay time                              | UNSIGNED16       | 16  |
|           | 11 | Drive off delay time                             | UNSIGNED16       | 16  |
| 0x8012    | 46 | STM Features Ch.1                                | UNKNOWN          |     |
|           | 01 | Operation mode                                   | INVALID          | 4   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 3   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 0   |
|           | 07 | SubIndex 007                                     | UNKNOWN          | 0   |
|           | 08 | Feedback type                                    | INVALID          | 1   |
|           | 09 | Invert motor polarity                            | BOOLEAN          | 1   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 7   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 0   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | SubIndex 017                                     | UNKNOWN          | 8   |
|           | 12 | SubIndex 018                                     | UNKNOWN          | 0   |
|           | 13 | SubIndex 019                                     | UNKNOWN          | 0   |
|           | 14 | SubIndex 020                                     | UNKNOWN          | 0   |
|           | 15 | SubIndex 021                                     | UNKNOWN          | 0   |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | SubIndex 023                                     | UNKNOWN          | 0   |
|           | 18 | SubIndex 024                                     | UNKNOWN          | 0   |
|           | 19 | SubIndex 025                                     | UNKNOWN          | 8   |
|           | 1a | SubIndex 026                                     | UNKNOWN          | 0   |
|           | 1b | SubIndex 027                                     | UNKNOWN          | 0   |
|           | 1c | SubIndex 028                                     | UNKNOWN          | 0   |
|           | 1d | SubIndex 029                                     | UNKNOWN          | 0   |
|           | 1e | SubIndex 030                                     | UNKNOWN          | 0   |
|           | 1f | SubIndex 031                                     | UNKNOWN          | 0   |
|           | 20 | SubIndex 032                                     | UNKNOWN          | 0   |
|           | 21 | SubIndex 033                                     | UNKNOWN          | 8   |
|           | 22 | SubIndex 034                                     | UNKNOWN          | 0   |
|           | 23 | SubIndex 035                                     | UNKNOWN          | 0   |
|           | 24 | SubIndex 036                                     | UNKNOWN          | 0   |
|           | 25 | SubIndex 037                                     | UNKNOWN          | 0   |
|           | 26 | SubIndex 038                                     | UNKNOWN          | 0   |
|           | 27 | SubIndex 039                                     | UNKNOWN          | 0   |
|           | 28 | SubIndex 040                                     | UNKNOWN          | 0   |
|           | 29 | SubIndex 041                                     | UNKNOWN          | 7   |
|           | 2a | SubIndex 042                                     | UNKNOWN          | 0   |
|           | 2b | SubIndex 043                                     | UNKNOWN          | 0   |
|           | 2c | SubIndex 044                                     | UNKNOWN          | 0   |
|           | 2d | SubIndex 045                                     | UNKNOWN          | 0   |
|           | 2e | SubIndex 046                                     | UNKNOWN          | 0   |
|           | 2f | SubIndex 047                                     | UNKNOWN          | 0   |
|           | 30 | Invert digital input 1                           | BOOLEAN          | 1   |
|           | 31 | Invert digital input 2                           | BOOLEAN          | 1   |
|           | 32 | Function for input 1                             | INVALID          | 4   |
|           | 33 | SubIndex 051                                     | UNKNOWN          | 0   |
|           | 34 | SubIndex 052                                     | UNKNOWN          | 0   |
|           | 35 | SubIndex 053                                     | UNKNOWN          | 0   |
|           | 36 | Function for input 2                             | INVALID          | 4   |
|           | 37 | SubIndex 055                                     | UNKNOWN          | 0   |
|           | 38 | SubIndex 056                                     | UNKNOWN          | 0   |
|           | 39 | SubIndex 057                                     | UNKNOWN          | 0   |
|           | 3a | SubIndex 058                                     | UNKNOWN          | 4   |
|           | 3b | SubIndex 059                                     | UNKNOWN          | 0   |
|           | 3c | SubIndex 060                                     | UNKNOWN          | 0   |
|           | 3d | SubIndex 061                                     | UNKNOWN          | 0   |
|           | 3e | SubIndex 062                                     | UNKNOWN          | 3   |
|           | 3f | SubIndex 063                                     | UNKNOWN          | 0   |
|           | 40 | SubIndex 064                                     | UNKNOWN          | 0   |
|           | 41 | SubIndex 065                                     | UNKNOWN          | 4   |
|           | 42 | SubIndex 066                                     | UNKNOWN          | 0   |
|           | 43 | SubIndex 067                                     | UNKNOWN          | 0   |
|           | 44 | SubIndex 068                                     | UNKNOWN          | 0   |
|           | 45 | Microstepping                                    | INVALID          | 4   |
|           | 46 | SubIndex 070                                     | UNKNOWN          | 8   |
| 0x8014    | 06 | STM Motor Settings 2 Ch.1                        | UNKNOWN          |     |
|           | 01 | Acceleration (maximum)                           | UNSIGNED16       | 16  |
|           | 02 | Acceleration threshold                           | UNSIGNED16       | 16  |
|           | 03 | Coil current (a>a,th)                            | UNSIGNED8        | 8   |
|           | 04 | Coil current (a<a,th)                            | UNSIGNED8        | 8   |
|           | 05 | Coil current (v=0, auto)                         | UNSIGNED8        | 8   |
|           | 06 | Coil current (v=0, manual)                       | UNSIGNED8        | 8   |

