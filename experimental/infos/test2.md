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
| 1     | EL3048           | 0xffff | 0x1001 | 0x00000002 | 0x0be83052 | 0x00130000 |

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

### Subdevice 1(0x1001): EL3048 

#### Addressing

| Property               | Value  |
|---                     |---     |
| Ring position          |     1  |
| Auto-increment address | 0xffff |
| Station address        | 0x1001 |

#### Identity

| Property         | Value |
|---               |---    |
| Order ID         | EL3048 |
| Name             | EL3048 8K. Ana. Eingang 0-20mA |
| Group            | AnaIn |
| Vendor ID        | 0x00000002 |
| Product code     | 0x0be83052 |
| Revision number  | 0x00130000 |
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
| coe_details.enable_SDO_complete_access | false |
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
    length: 0
    control:
        buffer_type                 esc.SyncManagerBufferType.buffered
        direction                   esc.SyncManagerDirection.output
        ECAT_event_enable           false
        DLS_user_event_enable       false
        watchdog_enable             false
    status:
        channel_enable              false
        repeat                      false
        reserved3                   0    
        DC_event_0_bus_access       false
        DC_event_0_local_access     false
    enable:
        enable                      false
        fixed_content               false
        virtual                     false
        OP_only                     false

##### SM3

    type: process_data_inputs
    physical start addr: 0x1180
    length: 32
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

    Inputs bit length: 256  
| PDO Index| SM| Mapped Index| Bits| Type| Name |
|---|---|---|---|---|---|
| 0x1a00 |   3 |           |  32 |                  | AI Standard Channel 1      |
|        |     | 0x6000:01 |   1 | BOOLEAN          | Status__Underrange         |
|        |     | 0x6000:02 |   1 | BOOLEAN          | Status__Overrange          |
|        |     | 0x6000:03 |   2 | BIT2             | Status__Limit 1            |
|        |     | 0x6000:05 |   2 | BIT2             | Status__Limit 2            |
|        |     | 0x6000:07 |   1 | BOOLEAN          | Status__Error              |
|        |     | 0x0000:00 |   1 | UNKNOWN          | Status__                   |
|        |     | 0x0000:00 |   6 | UNKNOWN          | Status__                   |
|        |     | 0x6000:0f |   1 | BOOLEAN          | Status__TxPDO State        |
|        |     | 0x6000:10 |   1 | BOOLEAN          | Status__TxPDO Toggle       |
|        |     | 0x6000:11 |  16 | INTEGER16        | Value                      |
| 0x1a01 | 255 |           |  16 |                  | AI Compact Channel 1       |
|        |     | 0x6000:11 |  16 | INTEGER16        | Value                      |
| 0x1a02 |   3 |           |  32 |                  | AI Standard Channel 2      |
|        |     | 0x6010:01 |   1 | BOOLEAN          | Status__Underrange         |
|        |     | 0x6010:02 |   1 | BOOLEAN          | Status__Overrange          |
|        |     | 0x6010:03 |   2 | BIT2             | Status__Limit 1            |
|        |     | 0x6010:05 |   2 | BIT2             | Status__Limit 2            |
|        |     | 0x6010:07 |   1 | BOOLEAN          | Status__Error              |
|        |     | 0x0000:00 |   1 | UNKNOWN          | Status__                   |
|        |     | 0x0000:00 |   6 | UNKNOWN          | Status__                   |
|        |     | 0x6010:0f |   1 | BOOLEAN          | Status__TxPDO State        |
|        |     | 0x6010:10 |   1 | BOOLEAN          | Status__TxPDO Toggle       |
|        |     | 0x6010:11 |  16 | INTEGER16        | Value                      |
| 0x1a03 | 255 |           |  16 |                  | AI Compact Channel 2       |
|        |     | 0x6010:11 |  16 | INTEGER16        | Value                      |
| 0x1a04 |   3 |           |  32 |                  | AI Standard Channel 3      |
|        |     | 0x6020:01 |   1 | BOOLEAN          | Status__Underrange         |
|        |     | 0x6020:02 |   1 | BOOLEAN          | Status__Overrange          |
|        |     | 0x6020:03 |   2 | BIT2             | Status__Limit 1            |
|        |     | 0x6020:05 |   2 | BIT2             | Status__Limit 2            |
|        |     | 0x6020:07 |   1 | BOOLEAN          | Status__Error              |
|        |     | 0x0000:00 |   1 | UNKNOWN          | Status__                   |
|        |     | 0x0000:00 |   6 | UNKNOWN          | Status__                   |
|        |     | 0x6020:0f |   1 | BOOLEAN          | Status__TxPDO State        |
|        |     | 0x6020:10 |   1 | BOOLEAN          | Status__TxPDO Toggle       |
|        |     | 0x6020:11 |  16 | INTEGER16        | Value                      |
| 0x1a05 | 255 |           |  16 |                  | AI Compact Channel 3       |
|        |     | 0x6020:11 |  16 | INTEGER16        | Value                      |
| 0x1a06 |   3 |           |  32 |                  | AI Standard Channel 4      |
|        |     | 0x6030:01 |   1 | BOOLEAN          | Status__Underrange         |
|        |     | 0x6030:02 |   1 | BOOLEAN          | Status__Overrange          |
|        |     | 0x6030:03 |   2 | BIT2             | Status__Limit 1            |
|        |     | 0x6030:05 |   2 | BIT2             | Status__Limit 2            |
|        |     | 0x6030:07 |   1 | BOOLEAN          | Status__Error              |
|        |     | 0x0000:00 |   1 | UNKNOWN          | Status__                   |
|        |     | 0x0000:00 |   6 | UNKNOWN          | Status__                   |
|        |     | 0x6030:0f |   1 | BOOLEAN          | Status__TxPDO State        |
|        |     | 0x6030:10 |   1 | BOOLEAN          | Status__TxPDO Toggle       |
|        |     | 0x6030:11 |  16 | INTEGER16        | Value                      |
| 0x1a07 | 255 |           |  16 |                  | AI Compact Channel 4       |
|        |     | 0x6030:11 |  16 | INTEGER16        | Value                      |
| 0x1a08 |   3 |           |  32 |                  | AI Standard Channel 5      |
|        |     | 0x6040:01 |   1 | BOOLEAN          | Status__Underrange         |
|        |     | 0x6040:02 |   1 | BOOLEAN          | Status__Overrange          |
|        |     | 0x6040:03 |   2 | BIT2             | Status__Limit 1            |
|        |     | 0x6040:05 |   2 | BIT2             | Status__Limit 2            |
|        |     | 0x6040:07 |   1 | BOOLEAN          | Status__Error              |
|        |     | 0x0000:00 |   1 | UNKNOWN          | Status__                   |
|        |     | 0x0000:00 |   6 | UNKNOWN          | Status__                   |
|        |     | 0x6040:0f |   1 | BOOLEAN          | Status__TxPDO State        |
|        |     | 0x6040:10 |   1 | BOOLEAN          | Status__TxPDO Toggle       |
|        |     | 0x6040:11 |  16 | INTEGER16        | Value                      |
| 0x1a09 | 255 |           |  16 |                  | AI Compact Channel 5       |
|        |     | 0x6040:11 |  16 | INTEGER16        | Value                      |
| 0x1a0a |   3 |           |  32 |                  | AI Standard Channel 6      |
|        |     | 0x6050:01 |   1 | BOOLEAN          | Status__Underrange         |
|        |     | 0x6050:02 |   1 | BOOLEAN          | Status__Overrange          |
|        |     | 0x6050:03 |   2 | BIT2             | Status__Limit 1            |
|        |     | 0x6050:05 |   2 | BIT2             | Status__Limit 2            |
|        |     | 0x6050:07 |   1 | BOOLEAN          | Status__Error              |
|        |     | 0x0000:00 |   1 | UNKNOWN          | Status__                   |
|        |     | 0x0000:00 |   6 | UNKNOWN          | Status__                   |
|        |     | 0x6050:0f |   1 | BOOLEAN          | Status__TxPDO State        |
|        |     | 0x6050:10 |   1 | BOOLEAN          | Status__TxPDO Toggle       |
|        |     | 0x6050:11 |  16 | INTEGER16        | Value                      |
| 0x1a0b | 255 |           |  16 |                  | AI Compact Channel 6       |
|        |     | 0x6050:11 |  16 | INTEGER16        | Value                      |
| 0x1a0c |   3 |           |  32 |                  | AI Standard Channel 7      |
|        |     | 0x6060:01 |   1 | BOOLEAN          | Status__Underrange         |
|        |     | 0x6060:02 |   1 | BOOLEAN          | Status__Overrange          |
|        |     | 0x6060:03 |   2 | BIT2             | Status__Limit 1            |
|        |     | 0x6060:05 |   2 | BIT2             | Status__Limit 2            |
|        |     | 0x6060:07 |   1 | BOOLEAN          | Status__Error              |
|        |     | 0x0000:00 |   1 | UNKNOWN          | Status__                   |
|        |     | 0x0000:00 |   6 | UNKNOWN          | Status__                   |
|        |     | 0x6060:0f |   1 | BOOLEAN          | Status__TxPDO State        |
|        |     | 0x6060:10 |   1 | BOOLEAN          | Status__TxPDO Toggle       |
|        |     | 0x6060:11 |  16 | INTEGER16        | Value                      |
| 0x1a0d | 255 |           |  16 |                  | AI Compact Channel 7       |
|        |     | 0x6060:11 |  16 | INTEGER16        | Value                      |
| 0x1a0e |   3 |           |  32 |                  | AI Standard Channel 8      |
|        |     | 0x6070:01 |   1 | BOOLEAN          | Status__Underrange         |
|        |     | 0x6070:02 |   1 | BOOLEAN          | Status__Overrange          |
|        |     | 0x6070:03 |   2 | BIT2             | Status__Limit 1            |
|        |     | 0x6070:05 |   2 | BIT2             | Status__Limit 2            |
|        |     | 0x6070:07 |   1 | BOOLEAN          | Status__Error              |
|        |     | 0x0000:00 |   1 | UNKNOWN          | Status__                   |
|        |     | 0x0000:00 |   6 | UNKNOWN          | Status__                   |
|        |     | 0x6070:0f |   1 | BOOLEAN          | Status__TxPDO State        |
|        |     | 0x6070:10 |   1 | BOOLEAN          | Status__TxPDO Toggle       |
|        |     | 0x6070:11 |  16 | INTEGER16        | Value                      |
| 0x1a0f | 255 |           |  16 |                  | AI Compact Channel 8       |
|        |     | 0x6070:11 |  16 | INTEGER16        | Value                      |

#### SII Catagory: RxPDOs

No RxPDOs catagory.

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
| 0x1a00 |   3 |           |  32 |         | |
|        |     | 0x6000:01 |   1 |         | |
|        |     | 0x6000:02 |   1 |         | |
|        |     | 0x6000:03 |   2 |         | |
|        |     | 0x6000:05 |   2 |         | |
|        |     | 0x6000:07 |   1 |         | |
|        |     |           |   1 | PADDING | |
|        |     |           |   6 | PADDING | |
|        |     | 0x6000:0f |   1 |         | |
|        |     | 0x6000:10 |   1 |         | |
|        |     | 0x6000:11 |  16 |         | |
| 0x1a02 |   3 |           |  32 |         | |
|        |     | 0x6010:01 |   1 |         | |
|        |     | 0x6010:02 |   1 |         | |
|        |     | 0x6010:03 |   2 |         | |
|        |     | 0x6010:05 |   2 |         | |
|        |     | 0x6010:07 |   1 |         | |
|        |     |           |   1 | PADDING | |
|        |     |           |   6 | PADDING | |
|        |     | 0x6010:0f |   1 |         | |
|        |     | 0x6010:10 |   1 |         | |
|        |     | 0x6010:11 |  16 |         | |
| 0x1a04 |   3 |           |  32 |         | |
|        |     | 0x6020:01 |   1 |         | |
|        |     | 0x6020:02 |   1 |         | |
|        |     | 0x6020:03 |   2 |         | |
|        |     | 0x6020:05 |   2 |         | |
|        |     | 0x6020:07 |   1 |         | |
|        |     |           |   1 | PADDING | |
|        |     |           |   6 | PADDING | |
|        |     | 0x6020:0f |   1 |         | |
|        |     | 0x6020:10 |   1 |         | |
|        |     | 0x6020:11 |  16 |         | |
| 0x1a06 |   3 |           |  32 |         | |
|        |     | 0x6030:01 |   1 |         | |
|        |     | 0x6030:02 |   1 |         | |
|        |     | 0x6030:03 |   2 |         | |
|        |     | 0x6030:05 |   2 |         | |
|        |     | 0x6030:07 |   1 |         | |
|        |     |           |   1 | PADDING | |
|        |     |           |   6 | PADDING | |
|        |     | 0x6030:0f |   1 |         | |
|        |     | 0x6030:10 |   1 |         | |
|        |     | 0x6030:11 |  16 |         | |
| 0x1a08 |   3 |           |  32 |         | |
|        |     | 0x6040:01 |   1 |         | |
|        |     | 0x6040:02 |   1 |         | |
|        |     | 0x6040:03 |   2 |         | |
|        |     | 0x6040:05 |   2 |         | |
|        |     | 0x6040:07 |   1 |         | |
|        |     |           |   1 | PADDING | |
|        |     |           |   6 | PADDING | |
|        |     | 0x6040:0f |   1 |         | |
|        |     | 0x6040:10 |   1 |         | |
|        |     | 0x6040:11 |  16 |         | |
| 0x1a0a |   3 |           |  32 |         | |
|        |     | 0x6050:01 |   1 |         | |
|        |     | 0x6050:02 |   1 |         | |
|        |     | 0x6050:03 |   2 |         | |
|        |     | 0x6050:05 |   2 |         | |
|        |     | 0x6050:07 |   1 |         | |
|        |     |           |   1 | PADDING | |
|        |     |           |   6 | PADDING | |
|        |     | 0x6050:0f |   1 |         | |
|        |     | 0x6050:10 |   1 |         | |
|        |     | 0x6050:11 |  16 |         | |
| 0x1a0c |   3 |           |  32 |         | |
|        |     | 0x6060:01 |   1 |         | |
|        |     | 0x6060:02 |   1 |         | |
|        |     | 0x6060:03 |   2 |         | |
|        |     | 0x6060:05 |   2 |         | |
|        |     | 0x6060:07 |   1 |         | |
|        |     |           |   1 | PADDING | |
|        |     |           |   6 | PADDING | |
|        |     | 0x6060:0f |   1 |         | |
|        |     | 0x6060:10 |   1 |         | |
|        |     | 0x6060:11 |  16 |         | |
| 0x1a0e |   3 |           |  32 |         | |
|        |     | 0x6070:01 |   1 |         | |
|        |     | 0x6070:02 |   1 |         | |
|        |     | 0x6070:03 |   2 |         | |
|        |     | 0x6070:05 |   2 |         | |
|        |     | 0x6070:07 |   1 |         | |
|        |     |           |   1 | PADDING | |
|        |     |           |   6 | PADDING | |
|        |     | 0x6070:0f |   1 |         | |
|        |     | 0x6070:10 |   1 |         | |
|        |     | 0x6070:11 |  16 |         | |


#### CoE: Object Description Lists

| List                             | Length |
|---                               |---     |
| all_objects                      |     79 |
| rx_pdo_mappable                  |      0 |
| tx_pdo_mappable                  |      8 |
| stored_for_device_replacement    |      8 |
| startup_parameters               |      8 |

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
| 0x1800    | 06 | AI TxPDO-Par Standard Ch.1                       | INVALID          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 0   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | Exclude TxPDOs                                   | OCTET_STRING     | 16  |
| 0x1801    | 06 | AI TxPDO-Par Compact Ch.1                        | INVALID          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 0   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | Exclude TxPDOs                                   | OCTET_STRING     | 16  |
| 0x1802    | 06 | AI TxPDO-Par Standard Ch.2                       | INVALID          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 0   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | Exclude TxPDOs                                   | OCTET_STRING     | 16  |
| 0x1803    | 06 | AI TxPDO-Par Compact Ch.2                        | INVALID          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 0   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | Exclude TxPDOs                                   | OCTET_STRING     | 16  |
| 0x1804    | 06 | AI TxPDO-Par Standard Ch.3                       | INVALID          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 0   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | Exclude TxPDOs                                   | OCTET_STRING     | 16  |
| 0x1805    | 06 | AI TxPDO-Par Compact Ch.3                        | INVALID          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 0   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | Exclude TxPDOs                                   | OCTET_STRING     | 16  |
| 0x1806    | 06 | AI TxPDO-Par Standard Ch.4                       | INVALID          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 0   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | Exclude TxPDOs                                   | OCTET_STRING     | 16  |
| 0x1807    | 06 | AI TxPDO-Par Compact Ch.4                        | INVALID          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 0   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | Exclude TxPDOs                                   | OCTET_STRING     | 16  |
| 0x1808    | 06 | AI TxPDO-Par Standard Ch.5                       | INVALID          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 0   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | Exclude TxPDOs                                   | OCTET_STRING     | 16  |
| 0x1809    | 06 | AI TxPDO-Par Compact Ch.5                        | INVALID          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 0   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | Exclude TxPDOs                                   | OCTET_STRING     | 16  |
| 0x180a    | 06 | AI TxPDO-Par Standard Ch.6                       | INVALID          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 0   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | Exclude TxPDOs                                   | OCTET_STRING     | 16  |
| 0x180b    | 06 | AI TxPDO-Par Compact Ch.6                        | INVALID          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 0   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | Exclude TxPDOs                                   | OCTET_STRING     | 16  |
| 0x180c    | 06 | AI TxPDO-Par Standard Ch.7                       | INVALID          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 0   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | Exclude TxPDOs                                   | OCTET_STRING     | 16  |
| 0x180d    | 06 | AI TxPDO-Par Compact Ch.7                        | INVALID          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 0   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | Exclude TxPDOs                                   | OCTET_STRING     | 16  |
| 0x180e    | 06 | AI TxPDO-Par Standard Ch.8                       | INVALID          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 0   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | Exclude TxPDOs                                   | OCTET_STRING     | 16  |
| 0x180f    | 06 | AI TxPDO-Par Compact Ch.8                        | INVALID          |     |
|           | 01 | SubIndex 001                                     | UNKNOWN          | 0   |
|           | 02 | SubIndex 002                                     | UNKNOWN          | 0   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | SubIndex 005                                     | UNKNOWN          | 0   |
|           | 06 | Exclude TxPDOs                                   | OCTET_STRING     | 16  |
| 0x1a00    | 0a | AI TxPDO-Map Standard Ch.1                       | PDO_MAPPING      |     |
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
| 0x1a01    | 01 | AI TxPDO-Map Compact Ch.1                        | PDO_MAPPING      |     |
|           | 01 | SubIndex 001                                     | UNSIGNED32       | 32  |
| 0x1a02    | 0a | AI TxPDO-Map Standard Ch.2                       | PDO_MAPPING      |     |
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
| 0x1a03    | 01 | AI TxPDO-Map Compact Ch.2                        | PDO_MAPPING      |     |
|           | 01 | SubIndex 001                                     | UNSIGNED32       | 32  |
| 0x1a04    | 0a | AI TxPDO-Map Standard Ch.3                       | PDO_MAPPING      |     |
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
| 0x1a05    | 01 | AI TxPDO-Map Compact Ch.3                        | PDO_MAPPING      |     |
|           | 01 | SubIndex 001                                     | UNSIGNED32       | 32  |
| 0x1a06    | 0a | AI TxPDO-Map Standard Ch.4                       | PDO_MAPPING      |     |
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
| 0x1a07    | 01 | AI TxPDO-Map Compact Ch.4                        | PDO_MAPPING      |     |
|           | 01 | SubIndex 001                                     | UNSIGNED32       | 32  |
| 0x1a08    | 0a | AI TxPDO-Map Standard Ch.5                       | PDO_MAPPING      |     |
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
| 0x1a09    | 01 | AI TxPDO-Map Compact Ch.5                        | PDO_MAPPING      |     |
|           | 01 | SubIndex 001                                     | UNSIGNED32       | 32  |
| 0x1a0a    | 0a | AI TxPDO-Map Standard Ch.6                       | PDO_MAPPING      |     |
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
| 0x1a0b    | 01 | AI TxPDO-Map Compact Ch.6                        | PDO_MAPPING      |     |
|           | 01 | SubIndex 001                                     | UNSIGNED32       | 32  |
| 0x1a0c    | 0a | AI TxPDO-Map Standard Ch.7                       | PDO_MAPPING      |     |
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
| 0x1a0d    | 01 | AI TxPDO-Map Compact Ch.7                        | PDO_MAPPING      |     |
|           | 01 | SubIndex 001                                     | UNSIGNED32       | 32  |
| 0x1a0e    | 0a | AI TxPDO-Map Standard Ch.8                       | PDO_MAPPING      |     |
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
| 0x1a0f    | 01 | AI TxPDO-Map Compact Ch.8                        | PDO_MAPPING      |     |
|           | 01 | SubIndex 001                                     | UNSIGNED32       | 32  |
| 0x1c00    | 04 | Sync manager type                                | UNSIGNED8        |     |
|           | 01 | SubIndex 001                                     | UNSIGNED8        | 8   |
|           | 02 | SubIndex 002                                     | UNSIGNED8        | 8   |
|           | 03 | SubIndex 003                                     | UNSIGNED8        | 8   |
|           | 04 | SubIndex 004                                     | UNSIGNED8        | 8   |
| 0x1c12    | 00 | RxPDO assign                                     | UNSIGNED16       |     |
| 0x1c13    | 08 | TxPDO assign                                     | UNSIGNED16       |     |
|           | 01 | SubIndex 001                                     | UNSIGNED16       | 16  |
|           | 02 | SubIndex 002                                     | UNSIGNED16       | 16  |
|           | 03 | SubIndex 003                                     | UNSIGNED16       | 16  |
|           | 04 | SubIndex 004                                     | UNSIGNED16       | 16  |
|           | 05 | SubIndex 005                                     | UNSIGNED16       | 16  |
|           | 06 | SubIndex 006                                     | UNSIGNED16       | 16  |
|           | 07 | SubIndex 007                                     | UNSIGNED16       | 16  |
|           | 08 | SubIndex 008                                     | UNSIGNED16       | 16  |
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
| 0x6000    | 11 | AI Inputs                                        | UNKNOWN          |     |
|           | 01 | Underrange                                       | BOOLEAN          | 1   |
|           | 02 | Overrange                                        | BOOLEAN          | 1   |
|           | 03 | Limit 1                                          | BIT2             | 2   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Limit 2                                          | BIT2             | 2   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 0   |
|           | 07 | Error                                            | BOOLEAN          | 1   |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 6   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | TxPDO State                                      | BOOLEAN          | 1   |
|           | 10 | TxPDO Toggle                                     | BOOLEAN          | 1   |
|           | 11 | Value                                            | INTEGER16        | 16  |
| 0x6010    | 11 | AI Inputs                                        | UNKNOWN          |     |
|           | 01 | Underrange                                       | BOOLEAN          | 1   |
|           | 02 | Overrange                                        | BOOLEAN          | 1   |
|           | 03 | Limit 1                                          | BIT2             | 2   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Limit 2                                          | BIT2             | 2   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 0   |
|           | 07 | Error                                            | BOOLEAN          | 1   |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 6   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | TxPDO State                                      | BOOLEAN          | 1   |
|           | 10 | TxPDO Toggle                                     | BOOLEAN          | 1   |
|           | 11 | Value                                            | INTEGER16        | 16  |
| 0x6020    | 11 | AI Inputs                                        | UNKNOWN          |     |
|           | 01 | Underrange                                       | BOOLEAN          | 1   |
|           | 02 | Overrange                                        | BOOLEAN          | 1   |
|           | 03 | Limit 1                                          | BIT2             | 2   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Limit 2                                          | BIT2             | 2   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 0   |
|           | 07 | Error                                            | BOOLEAN          | 1   |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 6   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | TxPDO State                                      | BOOLEAN          | 1   |
|           | 10 | TxPDO Toggle                                     | BOOLEAN          | 1   |
|           | 11 | Value                                            | INTEGER16        | 16  |
| 0x6030    | 11 | AI Inputs                                        | UNKNOWN          |     |
|           | 01 | Underrange                                       | BOOLEAN          | 1   |
|           | 02 | Overrange                                        | BOOLEAN          | 1   |
|           | 03 | Limit 1                                          | BIT2             | 2   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Limit 2                                          | BIT2             | 2   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 0   |
|           | 07 | Error                                            | BOOLEAN          | 1   |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 6   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | TxPDO State                                      | BOOLEAN          | 1   |
|           | 10 | TxPDO Toggle                                     | BOOLEAN          | 1   |
|           | 11 | Value                                            | INTEGER16        | 16  |
| 0x6040    | 11 | AI Inputs                                        | UNKNOWN          |     |
|           | 01 | Underrange                                       | BOOLEAN          | 1   |
|           | 02 | Overrange                                        | BOOLEAN          | 1   |
|           | 03 | Limit 1                                          | BIT2             | 2   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Limit 2                                          | BIT2             | 2   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 0   |
|           | 07 | Error                                            | BOOLEAN          | 1   |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 6   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | TxPDO State                                      | BOOLEAN          | 1   |
|           | 10 | TxPDO Toggle                                     | BOOLEAN          | 1   |
|           | 11 | Value                                            | INTEGER16        | 16  |
| 0x6050    | 11 | AI Inputs                                        | UNKNOWN          |     |
|           | 01 | Underrange                                       | BOOLEAN          | 1   |
|           | 02 | Overrange                                        | BOOLEAN          | 1   |
|           | 03 | Limit 1                                          | BIT2             | 2   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Limit 2                                          | BIT2             | 2   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 0   |
|           | 07 | Error                                            | BOOLEAN          | 1   |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 6   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | TxPDO State                                      | BOOLEAN          | 1   |
|           | 10 | TxPDO Toggle                                     | BOOLEAN          | 1   |
|           | 11 | Value                                            | INTEGER16        | 16  |
| 0x6060    | 11 | AI Inputs                                        | UNKNOWN          |     |
|           | 01 | Underrange                                       | BOOLEAN          | 1   |
|           | 02 | Overrange                                        | BOOLEAN          | 1   |
|           | 03 | Limit 1                                          | BIT2             | 2   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Limit 2                                          | BIT2             | 2   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 0   |
|           | 07 | Error                                            | BOOLEAN          | 1   |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 6   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | TxPDO State                                      | BOOLEAN          | 1   |
|           | 10 | TxPDO Toggle                                     | BOOLEAN          | 1   |
|           | 11 | Value                                            | INTEGER16        | 16  |
| 0x6070    | 11 | AI Inputs                                        | UNKNOWN          |     |
|           | 01 | Underrange                                       | BOOLEAN          | 1   |
|           | 02 | Overrange                                        | BOOLEAN          | 1   |
|           | 03 | Limit 1                                          | BIT2             | 2   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Limit 2                                          | BIT2             | 2   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 0   |
|           | 07 | Error                                            | BOOLEAN          | 1   |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 6   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | TxPDO State                                      | BOOLEAN          | 1   |
|           | 10 | TxPDO Toggle                                     | BOOLEAN          | 1   |
|           | 11 | Value                                            | INTEGER16        | 16  |
| 0x8000    | 18 | AI Settings                                      | UNKNOWN          |     |
|           | 01 | Enable user scale                                | BOOLEAN          | 1   |
|           | 02 | Presentation                                     | INVALID          | 3   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Siemens bits                                     | BOOLEAN          | 1   |
|           | 06 | Enable filter                                    | BOOLEAN          | 1   |
|           | 07 | Enable limit 1                                   | BOOLEAN          | 1   |
|           | 08 | Enable limit 2                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable user calibration                          | BOOLEAN          | 1   |
|           | 0b | Enable vendor calibration                        | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 2   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | Swap limit bits                                  | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 2   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | User scale offset                                | INTEGER16        | 16  |
|           | 12 | User scale gain                                  | INTEGER32        | 32  |
|           | 13 | Limit 1                                          | INTEGER16        | 16  |
|           | 14 | Limit 2                                          | INTEGER16        | 16  |
|           | 15 | Filter settings                                  | INVALID          | 16  |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | User calibration offset                          | INTEGER16        | 16  |
|           | 18 | User calibration gain                            | INTEGER16        | 16  |
| 0x800e    | 01 | AI Internal data                                 | UNKNOWN          |     |
|           | 01 | ADC raw value                                    | INTEGER16        | 16  |
| 0x800f    | 02 | AI Vendor data                                   | UNKNOWN          |     |
|           | 01 | Calibration offset                               | INTEGER16        | 16  |
|           | 02 | Calibration gain                                 | INTEGER16        | 16  |
| 0x8010    | 18 | AI Settings                                      | UNKNOWN          |     |
|           | 01 | Enable user scale                                | BOOLEAN          | 1   |
|           | 02 | Presentation                                     | INVALID          | 3   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Siemens bits                                     | BOOLEAN          | 1   |
|           | 06 | Enable filter                                    | BOOLEAN          | 1   |
|           | 07 | Enable limit 1                                   | BOOLEAN          | 1   |
|           | 08 | Enable limit 2                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable user calibration                          | BOOLEAN          | 1   |
|           | 0b | Enable vendor calibration                        | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 2   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | Swap limit bits                                  | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 2   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | User scale offset                                | INTEGER16        | 16  |
|           | 12 | User scale gain                                  | INTEGER32        | 32  |
|           | 13 | Limit 1                                          | INTEGER16        | 16  |
|           | 14 | Limit 2                                          | INTEGER16        | 16  |
|           | 15 | Filter settings                                  | INVALID          | 16  |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | User calibration offset                          | INTEGER16        | 16  |
|           | 18 | User calibration gain                            | INTEGER16        | 16  |
| 0x801e    | 01 | AI Internal data                                 | UNKNOWN          |     |
|           | 01 | ADC raw value                                    | INTEGER16        | 16  |
| 0x801f    | 02 | AI Vendor data                                   | UNKNOWN          |     |
|           | 01 | Calibration offset                               | INTEGER16        | 16  |
|           | 02 | Calibration gain                                 | INTEGER16        | 16  |
| 0x8020    | 18 | AI Settings                                      | UNKNOWN          |     |
|           | 01 | Enable user scale                                | BOOLEAN          | 1   |
|           | 02 | Presentation                                     | INVALID          | 3   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Siemens bits                                     | BOOLEAN          | 1   |
|           | 06 | Enable filter                                    | BOOLEAN          | 1   |
|           | 07 | Enable limit 1                                   | BOOLEAN          | 1   |
|           | 08 | Enable limit 2                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable user calibration                          | BOOLEAN          | 1   |
|           | 0b | Enable vendor calibration                        | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 2   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | Swap limit bits                                  | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 2   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | User scale offset                                | INTEGER16        | 16  |
|           | 12 | User scale gain                                  | INTEGER32        | 32  |
|           | 13 | Limit 1                                          | INTEGER16        | 16  |
|           | 14 | Limit 2                                          | INTEGER16        | 16  |
|           | 15 | Filter settings                                  | INVALID          | 16  |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | User calibration offset                          | INTEGER16        | 16  |
|           | 18 | User calibration gain                            | INTEGER16        | 16  |
| 0x802e    | 01 | AI Internal data                                 | UNKNOWN          |     |
|           | 01 | ADC raw value                                    | INTEGER16        | 16  |
| 0x802f    | 02 | AI Vendor data                                   | UNKNOWN          |     |
|           | 01 | Calibration offset                               | INTEGER16        | 16  |
|           | 02 | Calibration gain                                 | INTEGER16        | 16  |
| 0x8030    | 18 | AI Settings                                      | UNKNOWN          |     |
|           | 01 | Enable user scale                                | BOOLEAN          | 1   |
|           | 02 | Presentation                                     | INVALID          | 3   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Siemens bits                                     | BOOLEAN          | 1   |
|           | 06 | Enable filter                                    | BOOLEAN          | 1   |
|           | 07 | Enable limit 1                                   | BOOLEAN          | 1   |
|           | 08 | Enable limit 2                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable user calibration                          | BOOLEAN          | 1   |
|           | 0b | Enable vendor calibration                        | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 2   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | Swap limit bits                                  | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 2   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | User scale offset                                | INTEGER16        | 16  |
|           | 12 | User scale gain                                  | INTEGER32        | 32  |
|           | 13 | Limit 1                                          | INTEGER16        | 16  |
|           | 14 | Limit 2                                          | INTEGER16        | 16  |
|           | 15 | Filter settings                                  | INVALID          | 16  |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | User calibration offset                          | INTEGER16        | 16  |
|           | 18 | User calibration gain                            | INTEGER16        | 16  |
| 0x803e    | 01 | AI Internal data                                 | UNKNOWN          |     |
|           | 01 | ADC raw value                                    | INTEGER16        | 16  |
| 0x803f    | 02 | AI Vendor data                                   | UNKNOWN          |     |
|           | 01 | Calibration offset                               | INTEGER16        | 16  |
|           | 02 | Calibration gain                                 | INTEGER16        | 16  |
| 0x8040    | 18 | AI Settings                                      | UNKNOWN          |     |
|           | 01 | Enable user scale                                | BOOLEAN          | 1   |
|           | 02 | Presentation                                     | INVALID          | 3   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Siemens bits                                     | BOOLEAN          | 1   |
|           | 06 | Enable filter                                    | BOOLEAN          | 1   |
|           | 07 | Enable limit 1                                   | BOOLEAN          | 1   |
|           | 08 | Enable limit 2                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable user calibration                          | BOOLEAN          | 1   |
|           | 0b | Enable vendor calibration                        | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 2   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | Swap limit bits                                  | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 2   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | User scale offset                                | INTEGER16        | 16  |
|           | 12 | User scale gain                                  | INTEGER32        | 32  |
|           | 13 | Limit 1                                          | INTEGER16        | 16  |
|           | 14 | Limit 2                                          | INTEGER16        | 16  |
|           | 15 | Filter settings                                  | INVALID          | 16  |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | User calibration offset                          | INTEGER16        | 16  |
|           | 18 | User calibration gain                            | INTEGER16        | 16  |
| 0x804e    | 01 | AI Internal data                                 | UNKNOWN          |     |
|           | 01 | ADC raw value                                    | INTEGER16        | 16  |
| 0x804f    | 02 | AI Vendor data                                   | UNKNOWN          |     |
|           | 01 | Calibration offset                               | INTEGER16        | 16  |
|           | 02 | Calibration gain                                 | INTEGER16        | 16  |
| 0x8050    | 18 | AI Settings                                      | UNKNOWN          |     |
|           | 01 | Enable user scale                                | BOOLEAN          | 1   |
|           | 02 | Presentation                                     | INVALID          | 3   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Siemens bits                                     | BOOLEAN          | 1   |
|           | 06 | Enable filter                                    | BOOLEAN          | 1   |
|           | 07 | Enable limit 1                                   | BOOLEAN          | 1   |
|           | 08 | Enable limit 2                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable user calibration                          | BOOLEAN          | 1   |
|           | 0b | Enable vendor calibration                        | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 2   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | Swap limit bits                                  | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 2   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | User scale offset                                | INTEGER16        | 16  |
|           | 12 | User scale gain                                  | INTEGER32        | 32  |
|           | 13 | Limit 1                                          | INTEGER16        | 16  |
|           | 14 | Limit 2                                          | INTEGER16        | 16  |
|           | 15 | Filter settings                                  | INVALID          | 16  |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | User calibration offset                          | INTEGER16        | 16  |
|           | 18 | User calibration gain                            | INTEGER16        | 16  |
| 0x805e    | 01 | AI Internal data                                 | UNKNOWN          |     |
|           | 01 | ADC raw value                                    | INTEGER16        | 16  |
| 0x805f    | 02 | AI Vendor data                                   | UNKNOWN          |     |
|           | 01 | Calibration offset                               | INTEGER16        | 16  |
|           | 02 | Calibration gain                                 | INTEGER16        | 16  |
| 0x8060    | 18 | AI Settings                                      | UNKNOWN          |     |
|           | 01 | Enable user scale                                | BOOLEAN          | 1   |
|           | 02 | Presentation                                     | INVALID          | 3   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Siemens bits                                     | BOOLEAN          | 1   |
|           | 06 | Enable filter                                    | BOOLEAN          | 1   |
|           | 07 | Enable limit 1                                   | BOOLEAN          | 1   |
|           | 08 | Enable limit 2                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable user calibration                          | BOOLEAN          | 1   |
|           | 0b | Enable vendor calibration                        | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 2   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | Swap limit bits                                  | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 2   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | User scale offset                                | INTEGER16        | 16  |
|           | 12 | User scale gain                                  | INTEGER32        | 32  |
|           | 13 | Limit 1                                          | INTEGER16        | 16  |
|           | 14 | Limit 2                                          | INTEGER16        | 16  |
|           | 15 | Filter settings                                  | INVALID          | 16  |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | User calibration offset                          | INTEGER16        | 16  |
|           | 18 | User calibration gain                            | INTEGER16        | 16  |
| 0x806e    | 01 | AI Internal data                                 | UNKNOWN          |     |
|           | 01 | ADC raw value                                    | INTEGER16        | 16  |
| 0x806f    | 02 | AI Vendor data                                   | UNKNOWN          |     |
|           | 01 | Calibration offset                               | INTEGER16        | 16  |
|           | 02 | Calibration gain                                 | INTEGER16        | 16  |
| 0x8070    | 18 | AI Settings                                      | UNKNOWN          |     |
|           | 01 | Enable user scale                                | BOOLEAN          | 1   |
|           | 02 | Presentation                                     | INVALID          | 3   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Siemens bits                                     | BOOLEAN          | 1   |
|           | 06 | Enable filter                                    | BOOLEAN          | 1   |
|           | 07 | Enable limit 1                                   | BOOLEAN          | 1   |
|           | 08 | Enable limit 2                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable user calibration                          | BOOLEAN          | 1   |
|           | 0b | Enable vendor calibration                        | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 2   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | Swap limit bits                                  | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 2   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | User scale offset                                | INTEGER16        | 16  |
|           | 12 | User scale gain                                  | INTEGER32        | 32  |
|           | 13 | Limit 1                                          | INTEGER16        | 16  |
|           | 14 | Limit 2                                          | INTEGER16        | 16  |
|           | 15 | Filter settings                                  | INVALID          | 16  |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | User calibration offset                          | INTEGER16        | 16  |
|           | 18 | User calibration gain                            | INTEGER16        | 16  |
| 0x807e    | 01 | AI Internal data                                 | UNKNOWN          |     |
|           | 01 | ADC raw value                                    | INTEGER16        | 16  |
| 0x807f    | 02 | AI Vendor data                                   | UNKNOWN          |     |
|           | 01 | Calibration offset                               | INTEGER16        | 16  |
|           | 02 | Calibration gain                                 | INTEGER16        | 16  |
| 0xf000    | 02 | Modular device profile                           | INVALID          |     |
|           | 01 | Module index distance                            | UNSIGNED16       | 16  |
|           | 02 | Maximum number of modules                        | UNSIGNED16       | 16  |
| 0xf008    | 00 | Code word                                        | UNSIGNED32       |     |
| 0xf009    | 00 | Password protection                              | UNSIGNED32       |     |
| 0xf010    | 08 | Module list                                      | UNSIGNED32       |     |
|           | 01 | SubIndex 001                                     | UNSIGNED32       | 32  |
|           | 02 | SubIndex 002                                     | UNSIGNED32       | 32  |
|           | 03 | SubIndex 003                                     | UNSIGNED32       | 32  |
|           | 04 | SubIndex 004                                     | UNSIGNED32       | 32  |
|           | 05 | SubIndex 005                                     | UNSIGNED32       | 32  |
|           | 06 | SubIndex 006                                     | UNSIGNED32       | 32  |
|           | 07 | SubIndex 007                                     | UNSIGNED32       | 32  |
|           | 08 | SubIndex 008                                     | UNSIGNED32       | 32  |

#### CoE: Object Description List: RxPDO Mappable

| Index| Max Subindex / Subindex| Name| Type |
|---|---|---|---|

#### CoE: Object Description List: TxPDO Mappable

| Index| Max Subindex / Subindex| Name| Type |
|---|---|---|---|
| 0x6000    | 11 | AI Inputs                                        | UNKNOWN          |     |
|           | 01 | Underrange                                       | BOOLEAN          | 1   |
|           | 02 | Overrange                                        | BOOLEAN          | 1   |
|           | 03 | Limit 1                                          | BIT2             | 2   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Limit 2                                          | BIT2             | 2   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 0   |
|           | 07 | Error                                            | BOOLEAN          | 1   |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 6   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | TxPDO State                                      | BOOLEAN          | 1   |
|           | 10 | TxPDO Toggle                                     | BOOLEAN          | 1   |
|           | 11 | Value                                            | INTEGER16        | 16  |
| 0x6010    | 11 | AI Inputs                                        | UNKNOWN          |     |
|           | 01 | Underrange                                       | BOOLEAN          | 1   |
|           | 02 | Overrange                                        | BOOLEAN          | 1   |
|           | 03 | Limit 1                                          | BIT2             | 2   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Limit 2                                          | BIT2             | 2   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 0   |
|           | 07 | Error                                            | BOOLEAN          | 1   |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 6   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | TxPDO State                                      | BOOLEAN          | 1   |
|           | 10 | TxPDO Toggle                                     | BOOLEAN          | 1   |
|           | 11 | Value                                            | INTEGER16        | 16  |
| 0x6020    | 11 | AI Inputs                                        | UNKNOWN          |     |
|           | 01 | Underrange                                       | BOOLEAN          | 1   |
|           | 02 | Overrange                                        | BOOLEAN          | 1   |
|           | 03 | Limit 1                                          | BIT2             | 2   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Limit 2                                          | BIT2             | 2   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 0   |
|           | 07 | Error                                            | BOOLEAN          | 1   |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 6   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | TxPDO State                                      | BOOLEAN          | 1   |
|           | 10 | TxPDO Toggle                                     | BOOLEAN          | 1   |
|           | 11 | Value                                            | INTEGER16        | 16  |
| 0x6030    | 11 | AI Inputs                                        | UNKNOWN          |     |
|           | 01 | Underrange                                       | BOOLEAN          | 1   |
|           | 02 | Overrange                                        | BOOLEAN          | 1   |
|           | 03 | Limit 1                                          | BIT2             | 2   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Limit 2                                          | BIT2             | 2   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 0   |
|           | 07 | Error                                            | BOOLEAN          | 1   |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 6   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | TxPDO State                                      | BOOLEAN          | 1   |
|           | 10 | TxPDO Toggle                                     | BOOLEAN          | 1   |
|           | 11 | Value                                            | INTEGER16        | 16  |
| 0x6040    | 11 | AI Inputs                                        | UNKNOWN          |     |
|           | 01 | Underrange                                       | BOOLEAN          | 1   |
|           | 02 | Overrange                                        | BOOLEAN          | 1   |
|           | 03 | Limit 1                                          | BIT2             | 2   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Limit 2                                          | BIT2             | 2   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 0   |
|           | 07 | Error                                            | BOOLEAN          | 1   |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 6   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | TxPDO State                                      | BOOLEAN          | 1   |
|           | 10 | TxPDO Toggle                                     | BOOLEAN          | 1   |
|           | 11 | Value                                            | INTEGER16        | 16  |
| 0x6050    | 11 | AI Inputs                                        | UNKNOWN          |     |
|           | 01 | Underrange                                       | BOOLEAN          | 1   |
|           | 02 | Overrange                                        | BOOLEAN          | 1   |
|           | 03 | Limit 1                                          | BIT2             | 2   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Limit 2                                          | BIT2             | 2   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 0   |
|           | 07 | Error                                            | BOOLEAN          | 1   |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 6   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | TxPDO State                                      | BOOLEAN          | 1   |
|           | 10 | TxPDO Toggle                                     | BOOLEAN          | 1   |
|           | 11 | Value                                            | INTEGER16        | 16  |
| 0x6060    | 11 | AI Inputs                                        | UNKNOWN          |     |
|           | 01 | Underrange                                       | BOOLEAN          | 1   |
|           | 02 | Overrange                                        | BOOLEAN          | 1   |
|           | 03 | Limit 1                                          | BIT2             | 2   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Limit 2                                          | BIT2             | 2   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 0   |
|           | 07 | Error                                            | BOOLEAN          | 1   |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 6   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | TxPDO State                                      | BOOLEAN          | 1   |
|           | 10 | TxPDO Toggle                                     | BOOLEAN          | 1   |
|           | 11 | Value                                            | INTEGER16        | 16  |
| 0x6070    | 11 | AI Inputs                                        | UNKNOWN          |     |
|           | 01 | Underrange                                       | BOOLEAN          | 1   |
|           | 02 | Overrange                                        | BOOLEAN          | 1   |
|           | 03 | Limit 1                                          | BIT2             | 2   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Limit 2                                          | BIT2             | 2   |
|           | 06 | SubIndex 006                                     | UNKNOWN          | 0   |
|           | 07 | Error                                            | BOOLEAN          | 1   |
|           | 08 | SubIndex 008                                     | UNKNOWN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 6   |
|           | 0a | SubIndex 010                                     | UNKNOWN          | 0   |
|           | 0b | SubIndex 011                                     | UNKNOWN          | 0   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 0   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | SubIndex 014                                     | UNKNOWN          | 0   |
|           | 0f | TxPDO State                                      | BOOLEAN          | 1   |
|           | 10 | TxPDO Toggle                                     | BOOLEAN          | 1   |
|           | 11 | Value                                            | INTEGER16        | 16  |

#### CoE: Object Description List: Stored for Device Replacement

| Index| Max Subindex / Subindex| Name| Type |
|---|---|---|---|
| 0x8000    | 18 | AI Settings                                      | UNKNOWN          |     |
|           | 01 | Enable user scale                                | BOOLEAN          | 1   |
|           | 02 | Presentation                                     | INVALID          | 3   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Siemens bits                                     | BOOLEAN          | 1   |
|           | 06 | Enable filter                                    | BOOLEAN          | 1   |
|           | 07 | Enable limit 1                                   | BOOLEAN          | 1   |
|           | 08 | Enable limit 2                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable user calibration                          | BOOLEAN          | 1   |
|           | 0b | Enable vendor calibration                        | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 2   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | Swap limit bits                                  | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 2   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | User scale offset                                | INTEGER16        | 16  |
|           | 12 | User scale gain                                  | INTEGER32        | 32  |
|           | 13 | Limit 1                                          | INTEGER16        | 16  |
|           | 14 | Limit 2                                          | INTEGER16        | 16  |
|           | 15 | Filter settings                                  | INVALID          | 16  |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | User calibration offset                          | INTEGER16        | 16  |
|           | 18 | User calibration gain                            | INTEGER16        | 16  |
| 0x8010    | 18 | AI Settings                                      | UNKNOWN          |     |
|           | 01 | Enable user scale                                | BOOLEAN          | 1   |
|           | 02 | Presentation                                     | INVALID          | 3   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Siemens bits                                     | BOOLEAN          | 1   |
|           | 06 | Enable filter                                    | BOOLEAN          | 1   |
|           | 07 | Enable limit 1                                   | BOOLEAN          | 1   |
|           | 08 | Enable limit 2                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable user calibration                          | BOOLEAN          | 1   |
|           | 0b | Enable vendor calibration                        | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 2   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | Swap limit bits                                  | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 2   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | User scale offset                                | INTEGER16        | 16  |
|           | 12 | User scale gain                                  | INTEGER32        | 32  |
|           | 13 | Limit 1                                          | INTEGER16        | 16  |
|           | 14 | Limit 2                                          | INTEGER16        | 16  |
|           | 15 | Filter settings                                  | INVALID          | 16  |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | User calibration offset                          | INTEGER16        | 16  |
|           | 18 | User calibration gain                            | INTEGER16        | 16  |
| 0x8020    | 18 | AI Settings                                      | UNKNOWN          |     |
|           | 01 | Enable user scale                                | BOOLEAN          | 1   |
|           | 02 | Presentation                                     | INVALID          | 3   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Siemens bits                                     | BOOLEAN          | 1   |
|           | 06 | Enable filter                                    | BOOLEAN          | 1   |
|           | 07 | Enable limit 1                                   | BOOLEAN          | 1   |
|           | 08 | Enable limit 2                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable user calibration                          | BOOLEAN          | 1   |
|           | 0b | Enable vendor calibration                        | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 2   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | Swap limit bits                                  | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 2   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | User scale offset                                | INTEGER16        | 16  |
|           | 12 | User scale gain                                  | INTEGER32        | 32  |
|           | 13 | Limit 1                                          | INTEGER16        | 16  |
|           | 14 | Limit 2                                          | INTEGER16        | 16  |
|           | 15 | Filter settings                                  | INVALID          | 16  |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | User calibration offset                          | INTEGER16        | 16  |
|           | 18 | User calibration gain                            | INTEGER16        | 16  |
| 0x8030    | 18 | AI Settings                                      | UNKNOWN          |     |
|           | 01 | Enable user scale                                | BOOLEAN          | 1   |
|           | 02 | Presentation                                     | INVALID          | 3   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Siemens bits                                     | BOOLEAN          | 1   |
|           | 06 | Enable filter                                    | BOOLEAN          | 1   |
|           | 07 | Enable limit 1                                   | BOOLEAN          | 1   |
|           | 08 | Enable limit 2                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable user calibration                          | BOOLEAN          | 1   |
|           | 0b | Enable vendor calibration                        | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 2   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | Swap limit bits                                  | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 2   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | User scale offset                                | INTEGER16        | 16  |
|           | 12 | User scale gain                                  | INTEGER32        | 32  |
|           | 13 | Limit 1                                          | INTEGER16        | 16  |
|           | 14 | Limit 2                                          | INTEGER16        | 16  |
|           | 15 | Filter settings                                  | INVALID          | 16  |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | User calibration offset                          | INTEGER16        | 16  |
|           | 18 | User calibration gain                            | INTEGER16        | 16  |
| 0x8040    | 18 | AI Settings                                      | UNKNOWN          |     |
|           | 01 | Enable user scale                                | BOOLEAN          | 1   |
|           | 02 | Presentation                                     | INVALID          | 3   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Siemens bits                                     | BOOLEAN          | 1   |
|           | 06 | Enable filter                                    | BOOLEAN          | 1   |
|           | 07 | Enable limit 1                                   | BOOLEAN          | 1   |
|           | 08 | Enable limit 2                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable user calibration                          | BOOLEAN          | 1   |
|           | 0b | Enable vendor calibration                        | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 2   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | Swap limit bits                                  | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 2   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | User scale offset                                | INTEGER16        | 16  |
|           | 12 | User scale gain                                  | INTEGER32        | 32  |
|           | 13 | Limit 1                                          | INTEGER16        | 16  |
|           | 14 | Limit 2                                          | INTEGER16        | 16  |
|           | 15 | Filter settings                                  | INVALID          | 16  |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | User calibration offset                          | INTEGER16        | 16  |
|           | 18 | User calibration gain                            | INTEGER16        | 16  |
| 0x8050    | 18 | AI Settings                                      | UNKNOWN          |     |
|           | 01 | Enable user scale                                | BOOLEAN          | 1   |
|           | 02 | Presentation                                     | INVALID          | 3   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Siemens bits                                     | BOOLEAN          | 1   |
|           | 06 | Enable filter                                    | BOOLEAN          | 1   |
|           | 07 | Enable limit 1                                   | BOOLEAN          | 1   |
|           | 08 | Enable limit 2                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable user calibration                          | BOOLEAN          | 1   |
|           | 0b | Enable vendor calibration                        | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 2   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | Swap limit bits                                  | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 2   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | User scale offset                                | INTEGER16        | 16  |
|           | 12 | User scale gain                                  | INTEGER32        | 32  |
|           | 13 | Limit 1                                          | INTEGER16        | 16  |
|           | 14 | Limit 2                                          | INTEGER16        | 16  |
|           | 15 | Filter settings                                  | INVALID          | 16  |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | User calibration offset                          | INTEGER16        | 16  |
|           | 18 | User calibration gain                            | INTEGER16        | 16  |
| 0x8060    | 18 | AI Settings                                      | UNKNOWN          |     |
|           | 01 | Enable user scale                                | BOOLEAN          | 1   |
|           | 02 | Presentation                                     | INVALID          | 3   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Siemens bits                                     | BOOLEAN          | 1   |
|           | 06 | Enable filter                                    | BOOLEAN          | 1   |
|           | 07 | Enable limit 1                                   | BOOLEAN          | 1   |
|           | 08 | Enable limit 2                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable user calibration                          | BOOLEAN          | 1   |
|           | 0b | Enable vendor calibration                        | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 2   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | Swap limit bits                                  | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 2   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | User scale offset                                | INTEGER16        | 16  |
|           | 12 | User scale gain                                  | INTEGER32        | 32  |
|           | 13 | Limit 1                                          | INTEGER16        | 16  |
|           | 14 | Limit 2                                          | INTEGER16        | 16  |
|           | 15 | Filter settings                                  | INVALID          | 16  |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | User calibration offset                          | INTEGER16        | 16  |
|           | 18 | User calibration gain                            | INTEGER16        | 16  |
| 0x8070    | 18 | AI Settings                                      | UNKNOWN          |     |
|           | 01 | Enable user scale                                | BOOLEAN          | 1   |
|           | 02 | Presentation                                     | INVALID          | 3   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Siemens bits                                     | BOOLEAN          | 1   |
|           | 06 | Enable filter                                    | BOOLEAN          | 1   |
|           | 07 | Enable limit 1                                   | BOOLEAN          | 1   |
|           | 08 | Enable limit 2                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable user calibration                          | BOOLEAN          | 1   |
|           | 0b | Enable vendor calibration                        | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 2   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | Swap limit bits                                  | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 2   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | User scale offset                                | INTEGER16        | 16  |
|           | 12 | User scale gain                                  | INTEGER32        | 32  |
|           | 13 | Limit 1                                          | INTEGER16        | 16  |
|           | 14 | Limit 2                                          | INTEGER16        | 16  |
|           | 15 | Filter settings                                  | INVALID          | 16  |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | User calibration offset                          | INTEGER16        | 16  |
|           | 18 | User calibration gain                            | INTEGER16        | 16  |

#### CoE: Object Description List: Startup Parameters

| Index| Max Subindex / Subindex| Name| Type |
|---|---|---|---|
| 0x8000    | 18 | AI Settings                                      | UNKNOWN          |     |
|           | 01 | Enable user scale                                | BOOLEAN          | 1   |
|           | 02 | Presentation                                     | INVALID          | 3   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Siemens bits                                     | BOOLEAN          | 1   |
|           | 06 | Enable filter                                    | BOOLEAN          | 1   |
|           | 07 | Enable limit 1                                   | BOOLEAN          | 1   |
|           | 08 | Enable limit 2                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable user calibration                          | BOOLEAN          | 1   |
|           | 0b | Enable vendor calibration                        | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 2   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | Swap limit bits                                  | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 2   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | User scale offset                                | INTEGER16        | 16  |
|           | 12 | User scale gain                                  | INTEGER32        | 32  |
|           | 13 | Limit 1                                          | INTEGER16        | 16  |
|           | 14 | Limit 2                                          | INTEGER16        | 16  |
|           | 15 | Filter settings                                  | INVALID          | 16  |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | User calibration offset                          | INTEGER16        | 16  |
|           | 18 | User calibration gain                            | INTEGER16        | 16  |
| 0x8010    | 18 | AI Settings                                      | UNKNOWN          |     |
|           | 01 | Enable user scale                                | BOOLEAN          | 1   |
|           | 02 | Presentation                                     | INVALID          | 3   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Siemens bits                                     | BOOLEAN          | 1   |
|           | 06 | Enable filter                                    | BOOLEAN          | 1   |
|           | 07 | Enable limit 1                                   | BOOLEAN          | 1   |
|           | 08 | Enable limit 2                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable user calibration                          | BOOLEAN          | 1   |
|           | 0b | Enable vendor calibration                        | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 2   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | Swap limit bits                                  | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 2   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | User scale offset                                | INTEGER16        | 16  |
|           | 12 | User scale gain                                  | INTEGER32        | 32  |
|           | 13 | Limit 1                                          | INTEGER16        | 16  |
|           | 14 | Limit 2                                          | INTEGER16        | 16  |
|           | 15 | Filter settings                                  | INVALID          | 16  |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | User calibration offset                          | INTEGER16        | 16  |
|           | 18 | User calibration gain                            | INTEGER16        | 16  |
| 0x8020    | 18 | AI Settings                                      | UNKNOWN          |     |
|           | 01 | Enable user scale                                | BOOLEAN          | 1   |
|           | 02 | Presentation                                     | INVALID          | 3   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Siemens bits                                     | BOOLEAN          | 1   |
|           | 06 | Enable filter                                    | BOOLEAN          | 1   |
|           | 07 | Enable limit 1                                   | BOOLEAN          | 1   |
|           | 08 | Enable limit 2                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable user calibration                          | BOOLEAN          | 1   |
|           | 0b | Enable vendor calibration                        | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 2   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | Swap limit bits                                  | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 2   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | User scale offset                                | INTEGER16        | 16  |
|           | 12 | User scale gain                                  | INTEGER32        | 32  |
|           | 13 | Limit 1                                          | INTEGER16        | 16  |
|           | 14 | Limit 2                                          | INTEGER16        | 16  |
|           | 15 | Filter settings                                  | INVALID          | 16  |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | User calibration offset                          | INTEGER16        | 16  |
|           | 18 | User calibration gain                            | INTEGER16        | 16  |
| 0x8030    | 18 | AI Settings                                      | UNKNOWN          |     |
|           | 01 | Enable user scale                                | BOOLEAN          | 1   |
|           | 02 | Presentation                                     | INVALID          | 3   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Siemens bits                                     | BOOLEAN          | 1   |
|           | 06 | Enable filter                                    | BOOLEAN          | 1   |
|           | 07 | Enable limit 1                                   | BOOLEAN          | 1   |
|           | 08 | Enable limit 2                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable user calibration                          | BOOLEAN          | 1   |
|           | 0b | Enable vendor calibration                        | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 2   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | Swap limit bits                                  | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 2   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | User scale offset                                | INTEGER16        | 16  |
|           | 12 | User scale gain                                  | INTEGER32        | 32  |
|           | 13 | Limit 1                                          | INTEGER16        | 16  |
|           | 14 | Limit 2                                          | INTEGER16        | 16  |
|           | 15 | Filter settings                                  | INVALID          | 16  |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | User calibration offset                          | INTEGER16        | 16  |
|           | 18 | User calibration gain                            | INTEGER16        | 16  |
| 0x8040    | 18 | AI Settings                                      | UNKNOWN          |     |
|           | 01 | Enable user scale                                | BOOLEAN          | 1   |
|           | 02 | Presentation                                     | INVALID          | 3   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Siemens bits                                     | BOOLEAN          | 1   |
|           | 06 | Enable filter                                    | BOOLEAN          | 1   |
|           | 07 | Enable limit 1                                   | BOOLEAN          | 1   |
|           | 08 | Enable limit 2                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable user calibration                          | BOOLEAN          | 1   |
|           | 0b | Enable vendor calibration                        | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 2   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | Swap limit bits                                  | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 2   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | User scale offset                                | INTEGER16        | 16  |
|           | 12 | User scale gain                                  | INTEGER32        | 32  |
|           | 13 | Limit 1                                          | INTEGER16        | 16  |
|           | 14 | Limit 2                                          | INTEGER16        | 16  |
|           | 15 | Filter settings                                  | INVALID          | 16  |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | User calibration offset                          | INTEGER16        | 16  |
|           | 18 | User calibration gain                            | INTEGER16        | 16  |
| 0x8050    | 18 | AI Settings                                      | UNKNOWN          |     |
|           | 01 | Enable user scale                                | BOOLEAN          | 1   |
|           | 02 | Presentation                                     | INVALID          | 3   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Siemens bits                                     | BOOLEAN          | 1   |
|           | 06 | Enable filter                                    | BOOLEAN          | 1   |
|           | 07 | Enable limit 1                                   | BOOLEAN          | 1   |
|           | 08 | Enable limit 2                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable user calibration                          | BOOLEAN          | 1   |
|           | 0b | Enable vendor calibration                        | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 2   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | Swap limit bits                                  | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 2   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | User scale offset                                | INTEGER16        | 16  |
|           | 12 | User scale gain                                  | INTEGER32        | 32  |
|           | 13 | Limit 1                                          | INTEGER16        | 16  |
|           | 14 | Limit 2                                          | INTEGER16        | 16  |
|           | 15 | Filter settings                                  | INVALID          | 16  |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | User calibration offset                          | INTEGER16        | 16  |
|           | 18 | User calibration gain                            | INTEGER16        | 16  |
| 0x8060    | 18 | AI Settings                                      | UNKNOWN          |     |
|           | 01 | Enable user scale                                | BOOLEAN          | 1   |
|           | 02 | Presentation                                     | INVALID          | 3   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Siemens bits                                     | BOOLEAN          | 1   |
|           | 06 | Enable filter                                    | BOOLEAN          | 1   |
|           | 07 | Enable limit 1                                   | BOOLEAN          | 1   |
|           | 08 | Enable limit 2                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable user calibration                          | BOOLEAN          | 1   |
|           | 0b | Enable vendor calibration                        | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 2   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | Swap limit bits                                  | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 2   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | User scale offset                                | INTEGER16        | 16  |
|           | 12 | User scale gain                                  | INTEGER32        | 32  |
|           | 13 | Limit 1                                          | INTEGER16        | 16  |
|           | 14 | Limit 2                                          | INTEGER16        | 16  |
|           | 15 | Filter settings                                  | INVALID          | 16  |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | User calibration offset                          | INTEGER16        | 16  |
|           | 18 | User calibration gain                            | INTEGER16        | 16  |
| 0x8070    | 18 | AI Settings                                      | UNKNOWN          |     |
|           | 01 | Enable user scale                                | BOOLEAN          | 1   |
|           | 02 | Presentation                                     | INVALID          | 3   |
|           | 03 | SubIndex 003                                     | UNKNOWN          | 0   |
|           | 04 | SubIndex 004                                     | UNKNOWN          | 0   |
|           | 05 | Siemens bits                                     | BOOLEAN          | 1   |
|           | 06 | Enable filter                                    | BOOLEAN          | 1   |
|           | 07 | Enable limit 1                                   | BOOLEAN          | 1   |
|           | 08 | Enable limit 2                                   | BOOLEAN          | 1   |
|           | 09 | SubIndex 009                                     | UNKNOWN          | 1   |
|           | 0a | Enable user calibration                          | BOOLEAN          | 1   |
|           | 0b | Enable vendor calibration                        | BOOLEAN          | 1   |
|           | 0c | SubIndex 012                                     | UNKNOWN          | 2   |
|           | 0d | SubIndex 013                                     | UNKNOWN          | 0   |
|           | 0e | Swap limit bits                                  | BOOLEAN          | 1   |
|           | 0f | SubIndex 015                                     | UNKNOWN          | 2   |
|           | 10 | SubIndex 016                                     | UNKNOWN          | 0   |
|           | 11 | User scale offset                                | INTEGER16        | 16  |
|           | 12 | User scale gain                                  | INTEGER32        | 32  |
|           | 13 | Limit 1                                          | INTEGER16        | 16  |
|           | 14 | Limit 2                                          | INTEGER16        | 16  |
|           | 15 | Filter settings                                  | INVALID          | 16  |
|           | 16 | SubIndex 022                                     | UNKNOWN          | 0   |
|           | 17 | User calibration offset                          | INTEGER16        | 16  |
|           | 18 | User calibration gain                            | INTEGER16        | 16  |

