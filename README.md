# GatorCAT

![Tests](https://github.com/kj4tmp/gatorcat/actions/workflows/main.yml/badge.svg)

GatorCAT is an EtherCAT maindevice written for the zig programming language.

> [!WARNING]
> GatorCAT is **alpha** software. Using it today means participating in its development.

## Documentation

Examples can be found in [examples](doc/examples/). The examples can be built using `zig build examples`.

Documentation can be found in [doc](doc/README.md).

## Status

### Notably Working Features

- [x] no config, "just works" executable
    - [x] automatic configuration to reach OP for most subdevices, via SII and CoE
    - [x] process data published on zenoh
- [x] verifcation of the network contents against an ethercat network information struct (ENI)
- [x] cli for scanning a network to generate ENI
- [x] can manipulate process data
- [x] CoE startup parameters
- [x] CLI for scanning networks and getting information about subdevices
- [x] multi-OS support (Linux and Windows)

### Notably Missing Features

- [ ] distributed clocks
- [ ] Ethernet Over EtherCAT (EoE), also AoE, FoE, SoE, VoE
- [ ] user configurable processing of CoE emergency messages
- [ ] mapping the mailbox status into the process data
- [ ] async / event loop frames
- [ ] multi-threading friendly API
- [ ] linux XDP
- [ ] mac-os, embedded support
- [ ] allocation-free API
- [ ] cable redundancy
- [ ] EtherCAT Network Information(ENI) XML Parsing
- [ ] Segmented SDO transfer
- [ ] EEPROM write access
- [ ] Embedded friendly API / timers
- [ ] Network diagnosis in the CLI (CRC counters etc.)

## TODO

- [ ] validate individual pdo types at runtime (not just size of pdos)
- [ ] revise error handling
- [x] python package: hello world
- [ ] python package: message pack models
- [ ] python package: valkey driver
- [ ] make a custom `@tagName` that requires the parameter to be exhaustive

## Sponsors

List updated monthly.

- (empty)

Please consider [❤️ Sponsoring](https://github.com/sponsors/kj4tmp) if you depend on this project or just want to see it succeed.
