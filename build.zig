// This file is licensed under the CC0 1.0 license.
// See: https://creativecommons.org/publicdomain/zero/1.0/legalcode

const std = @import("std");
const libyaml_build = @import("./libyaml.build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const yaml_zig = b.addModule("libyaml", .{
        .source_file = .{ .path = "src/libyaml.zig" },
    });
    // yaml_zig.addIncludePath(.{ .path = b.getInstallPath(.header, "") });
    // _ = yaml_zig;

    const libyaml = libyaml_build.libyamlLib(b, .{
        .name = "libyaml",
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "yamltest",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibrary(libyaml);
    exe.addModule("yaml", yaml_zig);

    b.installArtifact(exe);
}
