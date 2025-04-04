const std = @import("std");

pub const BuildOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
};

pub fn buildRelease(
    b: *std.Build,
    step: *std.Build.Step,
) void {
    const targets: []const std.Target.Query = &.{
        .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .musl },
        // TODO: re-enable windows
        // .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
        .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .musl },
    };

    for (targets) |target| {
        const options: BuildOptions = .{
            .target = b.resolveTargetQuery(target),
            .optimize = .ReleaseSafe,
        };
        const gatorcat_module = b.addModule("gatorcat", .{
            .root_source_file = b.path("src/module/root.zig"),
            .target = options.target,
            .optimize = options.optimize,
        });
        // depend on the npcap sdk if we are building for windows
        switch (options.target.result.os.tag) {
            .windows => {
                if (b.lazyDependency("npcap", .{
                    .target = options.target,
                    .optimize = options.optimize,
                })) |npcap| {
                    gatorcat_module.addImport("npcap", npcap.module("npcap"));
                }
            },
            else => {},
        }
        const flags_module = b.dependency("flags", .{
            .target = options.target,
            .optimize = options.optimize,
        }).module("flags");
        const zbor_module = b.dependency("zbor", .{
            .target = options.target,
            .optimize = options.optimize,
        }).module("zbor");
        const zenoh_module = b.dependency("zenoh", .{
            .target = options.target,
            .optimize = options.optimize,
        }).module("zenoh");
        buildCli(
            b,
            step,
            .{ .target = options.target, .optimize = options.optimize },
            gatorcat_module,
            flags_module,
            zenoh_module,
            zbor_module,
            .{ .override = .{ .custom = target.zigTriple(b.allocator) catch @panic("oom") } },
        );
    }
}

pub fn build(b: *std.Build) void {
    const options: BuildOptions = .{
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    };

    const step_cli = b.default_step;
    const step_test = b.step("test", "Run unit tests.");
    const step_examples = b.step("examples", "Build examples.");
    const step_sim_test = b.step("sim-test", "Run the sim tests.");
    const step_release = b.step("release", "Build the release binaries.");
    // const step_docker = b.step("docker", "Build the docker container.");

    const step_ci = b.step("ci-test", "Run through full CI build and tests.");
    step_ci.dependOn(step_cli);
    step_ci.dependOn(step_test);
    step_ci.dependOn(step_examples);
    step_ci.dependOn(step_sim_test);
    step_ci.dependOn(step_release);

    // gatorcat module
    const module = b.addModule("gatorcat", .{
        .root_source_file = b.path("src/module/root.zig"),
        .target = options.target,
        .optimize = options.optimize,
    });
    // depend on the npcap sdk if we are building for windows
    switch (options.target.result.os.tag) {
        .windows => {
            if (b.lazyDependency("npcap", .{
                .target = options.target,
                .optimize = options.optimize,
            })) |npcap| {
                module.addImport("npcap", npcap.module("npcap"));
            }
        },
        else => {},
    }

    const flags_module = b.dependency("flags", .{
        .target = options.target,
        .optimize = options.optimize,
    }).module("flags");
    const zbor_module = b.dependency("zbor", .{
        .target = options.target,
        .optimize = options.optimize,
    }).module("zbor");
    const zenoh_module = b.dependency("zenoh", .{
        .target = options.target,
        .optimize = options.optimize,
    }).module("zenoh");

    // zig build
    buildCli(b, step_cli, options, module, flags_module, zenoh_module, zbor_module, .default);

    // zig build release
    buildRelease(b, step_release);

    // zig build test
    buildTest(b, step_test, options);

    // zig build examples
    buildExamples(b, step_examples, module, options);

    // zig build sim-test
    buildSimTest(b, step_sim_test, module, options);

    // docker image build
    // const docker_builder = b.addExecutable(.{
    //     .name = "docker-builder",
    //     .root_source_file = b.path("src/ci/release_docker.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // const docker_image_step = b.step("docker", "Build the gatorcat docker image");
    // docker_image_step.dependOn(&b.addRunArtifact(docker_builder).step);
    // docker_image_step.dependOn(&cli_install.step);

    // release binaries

    // const all_step = b.step("all", "Do everything");
    // all_step.dependOn(cli_step);
    // all_step.dependOn(test_step);
    // all_step.dependOn(examples_step);
    // all_step.dependOn(sim_test_step);
    // all_step.dependOn(cli_test_step);

    // b.default_step.dependOn(cli_step);
}

pub fn buildSimTest(
    b: *std.Build,
    step: *std.Build.Step,
    gatorcat_module: *std.Build.Module,
    options: BuildOptions,
) void {
    const sim_test = b.addTest(.{
        .root_source_file = b.path("test/sim/root.zig"),
        .target = options.target,
        .optimize = options.optimize,
    });
    sim_test.root_module.addImport("gatorcat", gatorcat_module);
    const run_sim_test = b.addRunArtifact(sim_test);
    step.dependOn(&run_sim_test.step);
}

pub fn buildExamples(
    b: *std.Build,
    step: *std.Build.Step,
    gatorcat_module: *std.Build.Module,
    options: BuildOptions,
) void {

    // example: simple
    const simple_example = b.addExecutable(.{
        .name = "simple",
        .target = options.target,
        .optimize = options.optimize,
        .root_source_file = b.path("doc/examples/simple/main.zig"),
    });
    simple_example.root_module.addImport("gatorcat", gatorcat_module);
    // using addInstallArtifact here so it only installs for the example step
    const example_install = b.addInstallArtifact(simple_example, .{});
    step.dependOn(&example_install.step);
    if (options.target.result.os.tag == .windows) simple_example.linkLibC();

    // example: simple2
    const simple2_example = b.addExecutable(.{
        .name = "simple2",
        .target = options.target,
        .optimize = options.optimize,
        .root_source_file = b.path("doc/examples/simple2/main.zig"),
    });
    simple2_example.root_module.addImport("gatorcat", gatorcat_module);
    // using addInstallArtifact here so it only installs for the example step
    const simple2_install = b.addInstallArtifact(simple2_example, .{});
    step.dependOn(&simple2_install.step);
    if (options.target.result.os.tag == .windows) simple2_example.linkLibC();

    // example: simple3
    const simple3_example = b.addExecutable(.{
        .name = "simple3",
        .target = options.target,
        .optimize = options.optimize,
        .root_source_file = b.path("doc/examples/simple3/main.zig"),
    });
    simple3_example.root_module.addImport("gatorcat", gatorcat_module);
    // using addInstallArtifact here so it only installs for the example step
    const simple3_install = b.addInstallArtifact(simple3_example, .{});
    step.dependOn(&simple3_install.step);
    if (options.target.result.os.tag == .windows) simple3_example.linkLibC();

    // example: simple4
    const simple4_example = b.addExecutable(.{
        .name = "simple4",
        .target = options.target,
        .optimize = options.optimize,
        .root_source_file = b.path("doc/examples/simple4/main.zig"),
    });
    simple4_example.root_module.addImport("gatorcat", gatorcat_module);
    // using addInstallArtifact here so it only installs for the example step
    const simple4_install = b.addInstallArtifact(simple4_example, .{});
    step.dependOn(&simple4_install.step);
    if (options.target.result.os.tag == .windows) simple4_example.linkLibC();
}

pub fn buildTest(
    b: *std.Build,
    step: *std.Build.Step,
    options: BuildOptions,
) void {
    const root_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/module/root.zig"),
        .target = options.target,
        .optimize = options.optimize,
    });
    const run_root_unit_tests = b.addRunArtifact(root_unit_tests);
    step.dependOn(&run_root_unit_tests.step);
}

pub fn buildCli(
    b: *std.Build,
    step: *std.Build.Step,
    options: BuildOptions,
    gatorcat_module: *std.Build.Module,
    flags_module: *std.Build.Module,
    zenoh_module: *std.Build.Module,
    zbor_module: *std.Build.Module,
    dest_dir: std.Build.Step.InstallArtifact.Options.Dir,
) void {
    const cli = b.addExecutable(.{
        .name = "gatorcat",
        .root_source_file = b.path("src/cli/main.zig"),
        .target = options.target,
        .optimize = options.optimize,
    });
    cli.root_module.addImport("gatorcat", gatorcat_module);
    cli.root_module.addImport("flags", flags_module);
    cli.root_module.addImport("zenoh", zenoh_module);
    cli.root_module.addImport("zbor", zbor_module);
    cli.root_module.addAnonymousImport("build_zig_zon", .{ .root_source_file = b.path("build.zig.zon") });
    if (options.target.result.os.tag == .windows) cli.linkLibC();

    const cli_install = b.addInstallArtifact(cli, .{ .dest_dir = dest_dir });
    step.dependOn(&cli_install.step);
}
