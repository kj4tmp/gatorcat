# GatorCAT

![Tests](https://github.com/kj4tmp/gatorcat/actions/workflows/main.yml/badge.svg)

GatorCAT is an EtherCAT maindevice written for the zig programming language.

> [!WARNING]
> GatorCAT is **alpha** software. Using it today means participating in its development.

## Documentation

Examples can be found in [examples](examples/). The examples can be built using `zig build examples`.

Documentation can be found in [doc](doc/README.md).

## Status

### Notably Working Features

- [x] automatic configuration to reach OP for most subdevices, via SII and CoE
- [x] verifcation of the network contents against an ethercat network information struct (ENI)
- [x] can manipulate process data
- [x] CoE startup parameters
- [x] CLI for scanning networks and getting information about subdevices
- [x] multi-OS support (Linux and Windows)

### Notably Missing Features

- [ ] distributed clocks
- [ ] Ethernet Over EtherCAT (EoE), also AoE, FoE, SoE, VoE
- [ ] user configurable processing of CoE emergency messages
- [ ] generate starting point for the network configuration (ENI) using the CLI
- [ ] mapping the mailbox status into the process data
- [ ] async / event loop frames
- [ ] multi-threading friendly API
- [ ] linux XDP
- [ ] mac-os, embedded support
- [ ] allocation-free API

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
