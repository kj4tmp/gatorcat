# GatorCAT Documentation

> [!WARNING]
> GatorCAT is **alpha** software. Using it today means participating in its development.
> This means you may find bugs or need features implemented before you can use GatorCAT effectively.

GatorCAT provides the following:

1. [GatorCAT CLI](#gatorcat-cli): a command-line interface executable for common tasks when working with EtherCAT networks, incuding running and scanning.
    > Run: automatically operate an EtherCAT network with zero configuration.

    > Scan: obtain information about the contents of the network.

    > Debug: (Work in progress) debug issues with your network.
1. [GatorCAT Module](#gatorcat-module): a zig module for writing applications that interact with EtherCAT networks.

## Zig Version

Please review the `minimum_zig_version` field of the [`build.zig.zon`](/build.zig.zon).

## GatorCAT CLI

### Installation

The CLI can be built from source:

1. Install the zig compiler. See [Zig Version](#zig-version).
1. Clone this repo.
1. Run `zig build` in the repo.
1. The executable will be named `gatorcat` and placed in `./zig-out/bin/`.

### Windows

On Windows, the GatorCAT CLI depends on [npcap](https://npcap.com/). It must be installed prior to running the CLI.
Please do not use windows for anything other than developer convienience (using the CLI, etc.).
Npcap has poor realtime performance and so does Windows in general.

### Linux

The CLI requires `CAP_NET_RAW` permissions to open raw sockets. The easiest way to acheive this is to run the CLI with `sudo`.

### Usage

Please review the help text printed with `gatorcat -h`.
There is also sub-help for each sub-command: `gatorcat scan -h`.

### Suggested Workflow

1. Run `gatorcat info --ifname eth0 > info.md` to create a human readable markdown file with information about the subdevices on your network.
1. Run `gatorcat scan --ifname eth0 > eni.zon` to create an ENI file for the network.
1. Run the network with `gatorcat run --ifname eth0 --cycle-time-us 10000 --zenoh-config-default --eni-file eni.zon`.
1. Observe data published on zenoh from ethercat.
    > The keys are defined in the `eni.zon`.

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


## MainDevice Class

Ref: ETG 1500

Class A Features

| Feature                           | Class A      | Class B      | Supported? |
| --------------------------------- | ------------ | ------------ | ---------- |
| service commands                  | shall if eni | shall if eni | yes        |
| irq                               | should       | should       | no         |
| subdevice device emulation        | shall        | shall        | yes?       |
| ecat state machine                | shall        | shall        | yes?       |
| error handling                    | shall        | shall        | yes        |
| vlan tagging                      | may          | may          | no         |
| ecat frames                       | shall        | shall        | yes        |
| udp frames                        | may          | may          | no         |
| cyclic pdo                        | shall        | shall        | yes        |
| multiple cyclic tasks             | may          | may          | no         |
| frame repetition                  | may          | may          | no         |
| online scanning                   |              |              | yes        |
| read ENI                          |              |              | yes*       |
| compare against eni               | shall        | shall        | yes        |
| explicit device id                | should       | should       | no?        |
| alias addressing                  | may          | may          | no         |
| eeprom read                       | shall        | shall        | yes        |
| eeprom write                      | may          | may          | no         |
| mailbox transfer                  | shall        | shall        | yes        |
| reslient mailbox                  | shall        | shall        | no         |
| multiple mailboxes                | may          | may          | no         |
| mailbox polling                   | shall        | shall        | no         |
| sdo upload download               | shall        | should       | no         |
| complete access                   | shall        | should       | yes        |
| sdo info                          | shall        | should       | yes        |
| emergency messages                | shall        | shall        | yes        |
| pdo in coe                        | may          | may          | no         |
| eoe                               | shall        | may          | no         |
| virtual switch                    | shall        | may          | no         |
| eoe endpoint to operation systems | should       | should       | no         |
| foe                               | shall        | may          | no         |
| firmware upload and download      | shall        | should       | no         |
| boot state                        | shall        | should       | no         |
| soe                               | shall        | should       | no         |
| aoe                               | should       | should       | no         |
| voe                               | may          | may          | no         |
| dc                                | shall        | may          | no         |
| continous prop delay measurement  | should       | should       | no         |
| sync window monitoring            | should       | should       | no         |
| sub to sub comms                  | shall        | shall        | no         |
| maindevice object dictionary      | should       | may          | no         |