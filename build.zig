// This file is licensed under the CC0 1.0 license.
// See: https://creativecommons.org/publicdomain/zero/1.0/legalcode

const std = @import("std");
const libyaml_build = @import("./libyaml.build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const yaml_zig = b.addModule("libyaml", .{
        .source_file = .{ .path = "src/yaml.zig" },
    });
    // yaml_zig.addIncludePath(.{ .path = b.getInstallPath(.header, "") });
    // _ = yaml_zig;

    const libyaml = libyaml_build.libyamlLib(b, .{
        .name = "libyaml",
        .target = target,
        .optimize = optimize,
    });

    const example_step = b.step("example", "build example");

    const ex_exe = b.addExecutable(.{
        .name = "yamltest",
        .root_source_file = .{ .path = "example/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    ex_exe.linkLibrary(libyaml);
    ex_exe.addModule("yaml", yaml_zig);

    const install = b.addInstallArtifact(ex_exe, .{});
    example_step.dependOn(&install.step);
}
