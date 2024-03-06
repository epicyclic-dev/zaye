// This file is licensed under the CC0 1.0 license.
// See: https://creativecommons.org/publicdomain/zero/1.0/legalcode

const std = @import("std");

const LibyamlOptions = struct {
    name: []const u8,
    target: std.zig.CrossTarget,
    optimize: std.builtin.OptimizeMode,
};

pub fn libyamlLib(
    b: *std.Build,
    options: LibyamlOptions,
) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = options.name,
        .target = options.target,
        .optimize = options.optimize,
    });

    const cflags = [_][]const u8{};

    lib.linkLibC();
    lib.addIncludePath(.{ .path = include_prefix });
    lib.addCSourceFiles(&sources, &cflags);
    lib.defineCMacro("YAML_VERSION_MAJOR", "0");
    lib.defineCMacro("YAML_VERSION_MINOR", "2");
    lib.defineCMacro("YAML_VERSION_PATCH", "5");
    lib.defineCMacro("YAML_VERSION_STRING", "\"0.2.5\"");

    b.installArtifact(lib);

    return lib;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = libyamlLib(b, .{ .name = "libyaml", .target = target, .optimize = optimize });
}

const libyaml_prefix = "deps/libyaml/";
const src_prefix = libyaml_prefix ++ "src/";
const include_prefix = libyaml_prefix ++ "include/";

const sources = [_][]const u8{
    src_prefix ++ "api.c",
    src_prefix ++ "dumper.c",
    src_prefix ++ "emitter.c",
    src_prefix ++ "loader.c",
    src_prefix ++ "parser.c",
    src_prefix ++ "reader.c",
    src_prefix ++ "scanner.c",
    src_prefix ++ "writer.c",
};
