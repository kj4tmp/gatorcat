# GatorCAT

![Tests](https://github.com/kj4tmp/gatorcat/actions/workflows/main.yml/badge.svg)

GatorCAT is an EtherCAT maindevice written for the zig programming language.

> [!WARNING]
> GatorCAT is **alpha** software. Using it today means participating in its development.

## Status

- [x] can reach OP
- [x] can manipulate process data
- [x] CoE supported
- [x] autoconfiguration from SII EEPROM
- [x] CLI for scanning networks

## Road to 0.1.0

- [x] multiple datagrams per frame
- [x] topology monitoring
- [x] NIC interface / vtable
- [x] windows support via npcap
- [ ] docs
- [x] re-organize examples
- [x] re-organize multi-platform code

## TODOs

- [ ] adjust order of declatations in files
- [ ] audit std.log statements
- [ ] re-organize files to separate lib from CLI
- [ ] support DC
- [ ] generic nic interface
- [ ] EoE
- [ ] FoE
- [ ] cable redundancy
- [ ] dynamic PDO assignment via CoE
- [ ] parse ENI.xml
- [ ] CLI for network diag, error counters etc
- [ ] distributed clocks
- [ ] topology monitoring
- [ ] emergency messages
- [ ] map mailbox status into process data
- [ ] calculate expected WKCs
- [ ] segmented SDO transfer
- [ ] eeprom write access
  - [ ] nic
    - [ ] linux / XDP
  - [ ] timers

## Windows Setup

1. Run `getmac /fo csv /v` in command prompt
2. ifname for npcap is of the format: `\Device\NPF_{538CF305-6539-480E-ACD9-BEE598E7AE8F}`
