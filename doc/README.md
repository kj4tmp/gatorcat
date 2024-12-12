# GatorCAT Documentation

> [!WARNING]
> GatorCAT is **alpha** software. Using it today means participating in its development.
> This means you may find bugs or need features implemented before you can use GatorCAT effectively.

## Installation

> TODO: show how to use gatorcat as a zig dependency

GatorCAT provides a CLI application that can be useful for getting information about ethercat networks.

The CLI application can be built and run by cloning this repo and running:

```sh
zig build
sudo zig-out/bin/gatorcat scan -h
```

which will provide the following help text:

```plaintext
Usage: gatorcat scan --ifname <ifname> [--ring-position <ring-position>]
                     [--recv-timeout-us <recv-timeout-us>]
                     [--eeprom-timeout-us <eeprom-timeout-us>]
                     [--INIT-timeout-us <INIT-timeout-us>]
                     [--PREOP-timeout-us <PREOP-timeout-us>]
                     [--mbx-timeout-us <mbx-timeout-us>] [-h | --help]

Options:

  --ifname            Network interface to use for the bus scan.
  --ring-position     Optionally specify only a single subdevice at this ring position to be scanned.
  --recv-timeout-us   Frame receive timeout in microseconds.
  --eeprom-timeout-us SII EEPROM timeout in microseconds.
  --INIT-timeout-us   state transition to INIT timeout in microseconds.
  --PREOP-timeout-us
  --mbx-timeout-us
  -h, --help          Show this help and exit
```

## Suggested Workflow

1. Build your EtherCAT network.
1. Use the GatorCAT CLI to scan the network.
1. Write your network configuration (ENI). See [example](../examples/simple/network_config.zig).
1. Write your application. See [example](../examples/simple/main.zig).
