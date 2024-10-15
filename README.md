# GatorCAT

GatorCAT is an EtherCAT maindevice written in the zig programming language.

This library is in extremely early development.

## Status

- [x] can reach OP
- [x] can manipulate process data
- [x] CoE supported
- [x] autoconfiguration from SII EEPROM

## TODOs

- [ ] adjust order of declatations in files
- [ ] audit std.log statements
- [ ] re-organize files to separate lib from CLI
- [ ] support DC
- [ ] multiple datagrams per frame
- [ ] frame queue / async
- [ ] generic nic interface
- [ ] EoE
- [ ] FoE
- [ ] cable redundancy
- [ ] dynamic PDO assignment via CoE
- [ ] parse ENI.xml
- [ ] CLI
  - [ ] scanning
  - [ ] network diag, error counters etc
- [ ] distributed clocks
- [ ] topology monitoring
- [ ] emergency messages
- [ ] map mailbox status into process data
- [ ] calculate expected WKCs
- [ ] segmented SDO transfer
- [ ] eeprom write access
- [ ] generic / embedded friendly interfaces
  - [ ] nic
    - [ ] windows / npcap support
    - [ ] linux / XDP
  - [ ] timers
