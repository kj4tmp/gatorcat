# Zig EtherCAT MainDevice

An EtherCAT MainDevice written in pure Zig.

This library is in extremely early development.

## Status

- [ ] OS/HW Support
  - [x] Big / Little Endianness
  - [x] linux
    - [x] link layers
      - [x] raw socket
    - [x] timer
      - [x] BOOTTIME
  - [ ] windows
    - [ ] link layers
      - [ ] npcap
  - [ ] embedded
    - [ ] link layers
      - [ ] generic link layer interface
    - [ ] timer
      - [ ] generic timer interface
- [ ] Basic Building Blocks
  - [x] Datagrams
    - [x] NOP
    - [x] APRD
    - [x] APWR
    - [x] APRW
    - [x] FPRD
    - [x] FPWR
    - [x] FPRW
    - [x] BRD
    - [x] BWR
    - [x] BRW
    - [x] LRD
    - [x] LWR
    - [x] LRW
    - [x] ARMW
    - [x] FRMW
  - [x] Multiple datagrams per frame
- [ ] SII
  - [x] Read SII EEPROM
  - [ ] Write SII EEPROM
- [ ] CoE
  - [ ] CoE Structures
    - [x] SDO Client
      - [x] Expedited
        - [x] Upload
        - [x] Download
      - [x] Normal
        - [x] Download
        - [x] Upload
      - [x] Segment
        - [x] Download
        - [x] Upload
    - [x] SDO Server
      - [x] Expedited
        - [x] Download
        - [x] Upload
      - [x] Normal
        - [x] Download
        - [x] Upload
      - [x] Segment
        - [x] Download
        - [x] Upload
      - [x] Abort SDO Transfer Request
      - [s] Emergency Request
  - [ ] SDO Read Expedited
  - [ ] SDO Read Normal
  - [ ] SDO Read Complete Access
  - [ ] SDO Write Expedited
  - [ ] SDO Write Normal
  - [ ] SDO Write Complete Access
  - [ ] SDO Errors
  - [ ] Emergency Messages
  - [ ] SDO Startup Parameters
- [ ] Configuration
  - [ ] INIT
    - [x] Wipe FMMUs.
    - [x] Wipe SMs.
    - [x] Set DL Control Register.
    - [x] Wipe CRC counters.
    - [x] Disable alias address.
    - [x] Request INIT.
    - [x] Set EEPROM control to maindevice.
    - [x] Count subdevices.
  - [ ] INIT -> PREOP
    - [x] Assign configured station addresses.
    - [x] Check subdevice identities.
    - [x] Program SMs
      - [x] Program default SM configuration
      - [x] Program SMs from SII
    - [ ] DC Configuration
      - [ ] Delay compensation
      - [ ] Offset compensation
      - [ ] Static drift compensation
  - [ ] PREOP -> SAFEOP
    - [ ] Set configuration objects via SDO.
    - [ ] Set RxPDO / TxPDO Assignment.
    - [ ] Set RxPDO / TxPDO Mapping.
    - [ ] Set SM2 for outputs.
    - [ ] Set SM3 for inputs.
    - [ ] Set FMMU0 (map outputs).
    - [ ] Set FMMU1 (map inputs).
    - [ ] DC Configuration
      - [ ] Configure Sync/LATCH unit.
      - [ ] Set SYNC cycle time.
      - [ ] Set DC start time.
      - [ ] Set DC SYNC OUT unit.
      - [ ] Set DC LATCH IN unit.
      - [ ] Start continuous drive compensation.
    - [ ] Begin cyclic process data.
    - [ ] Provide valid inputs.
  - [ ] SAFEOP -> OP
    - [ ] Provide valid outputs.
    - [ ] Maintain DC synchronization.

## Notes

### zig annoyances

1. Cannot tell if my tests have run or not (even with --summary all) !!!!!!!!!!!!!!!!!!
2. Packed structs are not well described in the language reference
3. Where to I look for the implementation of flags.parse? root.zig? I don't know where
anything is!
4. Cannot have arrays in packed structs. (See SM and FMMU structs).
5. For loops over slices / arrays: I have to look up the syntax every time.
6. Bitcasting packed structs can circumvent enum safety. <https://github.com/ziglang/zig/issues/21372>

### zig wins

big endian archs tests:

1. sudo apt install qemu-system-ppc qemu-utils binfmt-support qemu-user-static
2. zig build -fqemu -Dtarget=powerpc64-linux test --summary all

## TODOs

- [ ] align enums to style guide: <https://github.com/ziglang/zig/issues/2101>
- [ ] adjust order of declatations in files
