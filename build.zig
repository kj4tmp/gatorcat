const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // gatorcat module
    const module = b.addModule("gatorcat", .{
        .root_source_file = b.path("src/module/root.zig"),
    });
    // depend on the npcap sdk if we are building for windows
    switch (target.result.os.tag) {
        .windows => {
            const maybe_npcap_sdk = b.lazyDependency("npcap_sdk", .{
                .target = target,
                .optimize = optimize,
            });
            if (maybe_npcap_sdk) |npcap_sdk| {
                module.addIncludePath(npcap_sdk.path("Include"));

                switch (target.result.cpu.arch) {
                    .x86 => {
                        module.addObjectFile(npcap_sdk.path("Lib/wpcap.lib"));
                        module.addObjectFile(npcap_sdk.path("Lib/Packet.lib"));
                    },
                    .x86_64 => {
                        module.addObjectFile(npcap_sdk.path("Lib/x64/wpcap.lib"));
                        module.addObjectFile(npcap_sdk.path("Lib/x64/Packet.lib"));
                    },
                    .aarch64 => {
                        module.addObjectFile(npcap_sdk.path("Lib/ARM64/wpcap.lib"));
                        module.addObjectFile(npcap_sdk.path("Lib/ARM64/Packet.lib"));
                    },
                    else => {},
                }
            }
        },
        else => {},
    }

    // gatorcat module unit tests
    const root_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/module/root.zig"),
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
    cli.root_module.addImport("gatorcat", module);
    cli.root_module.addAnonymousImport("build_zig_zon", .{ .root_source_file = b.path("build.zig.zon") });

    // CLI tool dependencies
    const flags = b.dependency("flags", .{
        .target = target,
        .optimize = optimize,
    });
    cli.root_module.addImport("flags", flags.module("flags"));
    const zbor = b.dependency("zbor", .{
        .target = target,
        .optimize = optimize,
    });
    cli.root_module.addImport("zbor", zbor.module("zbor"));
    const zenoh = b.dependency("zenoh", .{
        .target = target,
        .optimize = optimize,
    });
    cli.root_module.addImport("zenoh", zenoh.module("zenoh"));
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
    const examples_step = b.step("doc/examples", "Build examples");
    const simple_example = b.addExecutable(.{
        .name = "simple",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("doc/examples/simple/main.zig"),
    });
    simple_example.root_module.addImport("gatorcat", module);
    // using addInstallArtifact here so it only installs for the example step
    const example_install = b.addInstallArtifact(simple_example, .{});
    examples_step.dependOn(&example_install.step);
    if (target.result.os.tag == .windows) simple_example.linkLibC();

    // example: simple2
    const simple2_example = b.addExecutable(.{
        .name = "simple2",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("doc/examples/simple2/main.zig"),
    });
    simple2_example.root_module.addImport("gatorcat", module);
    // using addInstallArtifact here so it only installs for the example step
    const simple2_install = b.addInstallArtifact(simple2_example, .{});
    examples_step.dependOn(&simple2_install.step);
    if (target.result.os.tag == .windows) simple2_example.linkLibC();

    // example: simple3
    const simple3_example = b.addExecutable(.{
        .name = "simple3",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("doc/examples/simple3/main.zig"),
    });
    simple3_example.root_module.addImport("gatorcat", module);
    // using addInstallArtifact here so it only installs for the example step
    const simple3_install = b.addInstallArtifact(simple3_example, .{});
    examples_step.dependOn(&simple3_install.step);
    if (target.result.os.tag == .windows) simple3_example.linkLibC();

    // example: simple4
    const simple4_example = b.addExecutable(.{
        .name = "simple4",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("doc/examples/simple4/main.zig"),
    });
    simple4_example.root_module.addImport("gatorcat", module);
    // using addInstallArtifact here so it only installs for the example step
    const simple4_install = b.addInstallArtifact(simple4_example, .{});
    examples_step.dependOn(&simple4_install.step);
    if (target.result.os.tag == .windows) simple4_example.linkLibC();

    // sim tests
    const sim_test = b.addTest(.{
        .root_source_file = b.path("test/sim/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_sim_test = b.addRunArtifact(sim_test);
    const sim_test_step = b.step("sim_test", "Run sim tests");
    sim_test_step.dependOn(&run_sim_test.step);
    sim_test.root_module.addImport("gatorcat", module);

    // cli tests

    const cli_test = b.addTest(.{
        .root_source_file = cli.root_module.root_source_file,
        .target = target,
        .optimize = optimize,
    });
    const run_cli_test = b.addRunArtifact(cli_test);
    const cli_test_step = b.step("cli_test", "Run cli tests");
    cli_test_step.dependOn(&run_cli_test.step);
    cli_test.root_module.addImport("gatorcat", module);
    cli_test.root_module.addImport("zbor", zbor.module("zbor"));

    // docker image build
    const docker_builder = b.addExecutable(.{
        .name = "docker-builder",
        .root_source_file = b.path("src/ci/release_docker.zig"),
        .target = target,
        .optimize = optimize,
    });
    const docker_image_step = b.step("docker", "Build the gatorcat docker image");
    docker_image_step.dependOn(&b.addRunArtifact(docker_builder).step);
    docker_image_step.dependOn(&cli_install.step);

    const all_step = b.step("all", "Do everything");
    all_step.dependOn(cli_step);
    all_step.dependOn(test_step);
    all_step.dependOn(examples_step);
    all_step.dependOn(sim_test_step);
    all_step.dependOn(cli_test_step);

    b.default_step.dependOn(cli_step);
}
