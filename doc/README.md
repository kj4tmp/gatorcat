# GatorCAT Documentation

> [!WARNING]
> GatorCAT is **alpha** software. Using it today means participating in its development.
> This means you may find bugs or need features implemented before you can use GatorCAT effectively.

GatorCAT provides the following:

1. [GatorCAT CLI](#gatorcat-cli): a command-line interface executable for common tasks when working with EtherCAT networks (scanning etc.).
1. [GatorCAT Module](#gatorcat-module): a zig module for writing applications that interact with EtherCAT networks.

## Zig Version

GatorCAT targets zig master for now. We plan to stop targetting master once 0.14.0 is released.

## GatorCAT CLI

### Installation

The CLI can be build from source:

1. Clone this repo
1. Run `zig build` in the repo
1. The executable will be named `gatorcat` and placed in `./zig-out/bin/`

### Windows

On Windows, the GatorCAT CLI depends on [npcap](https://npcap.com/). It must be installed prior to running the CLI.
Please do not use windows for anything other than developer convienience (using the CLI, etc.).
Npcap has poor realtime performance and so does Windows in general.

### Linux

The CLI requires `CAP_NET_RAW` permissions to open raw sockets. The easiest way to acheive this is to run the CLI with `sudo`.

### Usage

The CLI has the following help text:

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

## GatorCAT Module

### Using the Zig Package Manager

To add GatorCAT to your project as a dependency, run:

```sh
zig fetch --save git+https://github.com/kj4tmp/gatorcat
```

Then add the following to your build.zig:

```zig
// assuming you have an existing executable called `exe`
const gatorcat = b.dependency("gatorcat", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("gatorcat", gatorcat.module("gatorcat"));
```

And import the library to begin using it:

```zig
const gcat = @import("gatorcat");
```

### Windows Support

To provide windows support, GatorCAT depends on [npcap](https://npcap.com/). Npcap does not need to be installed
to build for windows targets, but it must be installed on the target when running resulting executables.

To obtain the name of network interfaces on windows:

1. Run `getmac /fo csv /v` in command prompt
2. ifname for npcap is of the format: `\Device\NPF_{538CF305-6539-480E-ACD9-BEE598E7AE8F}`

### Suggested Workflow

1. Build your EtherCAT network.
1. Use the [GatorCAT CLI](#gatorcat-cli) to scan the network.
1. Write your network configuration (ENI). See [example](../examples/simple/network_config.zig).
1. Write your application. See [example](../examples/simple/main.zig).
