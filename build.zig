const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // module for users of this library
    const ecm_module = b.addModule("ecm", .{
        .root_source_file = b.path("src/root.zig"),
    });

    // CLI tool
    const cli_tool = b.addExecutable(.{
        .name = "ecm-cli",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    cli_tool.root_module.addImport("ecm", ecm_module);

    const flags = b.dependency("flags", .{
        .target = target,
        .optimize = optimize,
    });
    cli_tool.root_module.addImport("flags", flags.module("flags"));
    b.installArtifact(cli_tool);

    // root module unit tests
    const root_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_root_unit_tests = b.addRunArtifact(root_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_root_unit_tests.step);

    // example
    const example_step = b.step("example", "Build example");
    const example = b.addExecutable(.{
        .name = "example",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("example/main.zig"),
    });
    example.root_module.addImport("ecm", ecm_module);
    // using addInstallArtifact here so it only installs for the example step
    const example_install = b.addInstallArtifact(example, .{});
    example_step.dependOn(&example_install.step);
}
