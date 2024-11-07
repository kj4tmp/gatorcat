const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // gatorcat module
    const gatorcat_module = b.addModule("gatorcat", .{
        .root_source_file = b.path("src/root.zig"),
    });
    // depend on the npcap sdk if we are building for windows
    switch (target.result.os.tag) {
        .windows => {
            const maybe_npcap_sdk = b.lazyDependency("npcap_sdk", .{
                .target = target,
                .optimize = optimize,
            });
            if (maybe_npcap_sdk) |npcap_sdk| {
                gatorcat_module.addIncludePath(npcap_sdk.path("Include"));

                switch (target.result.cpu.arch) {
                    .x86 => {
                        gatorcat_module.addObjectFile(npcap_sdk.path("Lib/wpcap.lib"));
                        gatorcat_module.addObjectFile(npcap_sdk.path("Lib/Packet.lib"));
                    },
                    .x86_64 => {
                        gatorcat_module.addObjectFile(npcap_sdk.path("Lib/x64/wpcap.lib"));
                        gatorcat_module.addObjectFile(npcap_sdk.path("Lib/x64/Packet.lib"));
                    },
                    .aarch64 => {
                        gatorcat_module.addObjectFile(npcap_sdk.path("Lib/ARM64/wpcap.lib"));
                        gatorcat_module.addObjectFile(npcap_sdk.path("Lib/ARM64/Packet.lib"));
                    },
                    else => {},
                }
            }
        },
        else => {},
    }

    // gatorcat module unit tests
    const root_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_root_unit_tests = b.addRunArtifact(root_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_root_unit_tests.step);

    // CLI tool
    const cli_tool = b.addExecutable(.{
        .name = "gatorcat",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    cli_tool.root_module.addImport("gatorcat", gatorcat_module);

    // CLI tool dependencies
    const flags = b.dependency("flags", .{
        .target = target,
        .optimize = optimize,
    });
    cli_tool.root_module.addImport("flags", flags.module("flags"));
    // depend on the npcap sdk if we are building for windows
    switch (target.result.os.tag) {
        .windows => {
            const maybe_npcap_sdk = b.lazyDependency("npcap_sdk", .{
                .target = target,
                .optimize = optimize,
            });
            if (maybe_npcap_sdk) |npcap_sdk| {
                cli_tool.addIncludePath(npcap_sdk.path("Include"));
                cli_tool.linkLibC();

                switch (target.result.cpu.arch) {
                    .x86 => {
                        cli_tool.addObjectFile(npcap_sdk.path("Lib/wpcap.lib"));
                        cli_tool.addObjectFile(npcap_sdk.path("Lib/Packet.lib"));
                    },
                    .x86_64 => {
                        cli_tool.addObjectFile(npcap_sdk.path("Lib/x64/wpcap.lib"));
                        cli_tool.addObjectFile(npcap_sdk.path("Lib/x64/Packet.lib"));
                    },
                    .aarch64 => {
                        cli_tool.addObjectFile(npcap_sdk.path("Lib/ARM64/wpcap.lib"));
                        cli_tool.addObjectFile(npcap_sdk.path("Lib/ARM64/Packet.lib"));
                    },
                    else => {},
                }
            }
        },
        else => {},
    }
    b.installArtifact(cli_tool);

    // example
    const example_step = b.step("example", "Build example");
    const example = b.addExecutable(.{
        .name = "example",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("example/main.zig"),
    });
    example.root_module.addImport("gatorcat", gatorcat_module);
    // using addInstallArtifact here so it only installs for the example step
    const example_install = b.addInstallArtifact(example, .{});
    example_step.dependOn(&example_install.step);
}
