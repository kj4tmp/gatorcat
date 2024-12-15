const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // gatorcat module
    const lib = b.addModule("gatorcat", .{
        .root_source_file = b.path("src/lib/root.zig"),
    });
    // depend on the npcap sdk if we are building for windows
    switch (target.result.os.tag) {
        .windows => {
            const maybe_npcap_sdk = b.lazyDependency("npcap_sdk", .{
                .target = target,
                .optimize = optimize,
            });
            if (maybe_npcap_sdk) |npcap_sdk| {
                lib.addIncludePath(npcap_sdk.path("Include"));

                switch (target.result.cpu.arch) {
                    .x86 => {
                        lib.addObjectFile(npcap_sdk.path("Lib/wpcap.lib"));
                        lib.addObjectFile(npcap_sdk.path("Lib/Packet.lib"));
                    },
                    .x86_64 => {
                        lib.addObjectFile(npcap_sdk.path("Lib/x64/wpcap.lib"));
                        lib.addObjectFile(npcap_sdk.path("Lib/x64/Packet.lib"));
                    },
                    .aarch64 => {
                        lib.addObjectFile(npcap_sdk.path("Lib/ARM64/wpcap.lib"));
                        lib.addObjectFile(npcap_sdk.path("Lib/ARM64/Packet.lib"));
                    },
                    else => {},
                }
            }
        },
        else => {},
    }

    // gatorcat module unit tests
    const root_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/lib/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_root_unit_tests = b.addRunArtifact(root_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_root_unit_tests.step);

    // CLI tool step
    const cli_step = b.step("cli", "Build the GatorCAT CLI tool");
    const cli = b.addExecutable(.{
        .name = "gatorcat",
        .root_source_file = b.path("src/cli/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    cli.root_module.addImport("gatorcat", lib);

    // CLI tool dependencies
    const flags = b.dependency("flags", .{
        .target = target,
        .optimize = optimize,
    });
    cli.root_module.addImport("flags", flags.module("flags"));
    // depend on the npcap sdk if we are building for windows
    switch (target.result.os.tag) {
        .windows => {
            const maybe_npcap_sdk = b.lazyDependency("npcap_sdk", .{
                .target = target,
                .optimize = optimize,
            });
            if (maybe_npcap_sdk) |npcap_sdk| {
                cli.addIncludePath(npcap_sdk.path("Include"));
                cli.linkLibC();

                switch (target.result.cpu.arch) {
                    .x86 => {
                        cli.addObjectFile(npcap_sdk.path("Lib/wpcap.lib"));
                        cli.addObjectFile(npcap_sdk.path("Lib/Packet.lib"));
                    },
                    .x86_64 => {
                        cli.addObjectFile(npcap_sdk.path("Lib/x64/wpcap.lib"));
                        cli.addObjectFile(npcap_sdk.path("Lib/x64/Packet.lib"));
                    },
                    .aarch64 => {
                        cli.addObjectFile(npcap_sdk.path("Lib/ARM64/wpcap.lib"));
                        cli.addObjectFile(npcap_sdk.path("Lib/ARM64/Packet.lib"));
                    },
                    else => {},
                }
            }
        },
        else => {},
    }
    const cli_install = b.addInstallArtifact(cli, .{});
    cli_step.dependOn(&cli_install.step);

    // example: simple
    const examples_step = b.step("examples", "Build examples");
    const simple_example = b.addExecutable(.{
        .name = "simple",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("examples/simple/main.zig"),
    });
    simple_example.root_module.addImport("gatorcat", lib);
    // using addInstallArtifact here so it only installs for the example step
    const example_install = b.addInstallArtifact(simple_example, .{});
    examples_step.dependOn(&example_install.step);
    if (target.result.os.tag == .windows) simple_example.linkLibC();

    // example: simple2
    const simple2_example = b.addExecutable(.{
        .name = "simple2",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("examples/simple2/main.zig"),
    });
    simple2_example.root_module.addImport("gatorcat", lib);
    // using addInstallArtifact here so it only installs for the example step
    const simple2_install = b.addInstallArtifact(simple2_example, .{});
    examples_step.dependOn(&simple2_install.step);
    if (target.result.os.tag == .windows) simple2_example.linkLibC();

    const all_step = b.step("all", "Do everything");
    all_step.dependOn(cli_step);
    all_step.dependOn(test_step);
    all_step.dependOn(examples_step);

    b.default_step.dependOn(cli_step);
}
