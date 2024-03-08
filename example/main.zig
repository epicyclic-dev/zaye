const std = @import("std");

const yaml = @import("yaml");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const slurp = std.fs.cwd().readFileAlloc(
        allocator,
        "test.yaml",
        1024 * 1024 * 1024,
    ) catch |err| {
        std.debug.print("couldn't open test.yaml in the cwd\n", .{});
        return err;
    };
    defer allocator.free(slurp);

    var diag = yaml.ParseDiagnostic{ .message = "?????" };
    const doc = yaml.Document.fromString(allocator, slurp, &diag) catch |err| {
        std.debug.print(
            "Failed to parse line: {d}, col: {d}: {s}\n",
            .{ diag.line, diag.col, diag.message },
        );
        return err;
    };
    defer doc.deinit();

    try std.json.stringify(doc.root, .{}, std.io.getStdOut().writer());
}
