const std = @import("std");

const yaml = @import("yaml");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const slurp = try std.fs.cwd().readFileAlloc(
        allocator,
        "test.yaml",
        1024 * 1024 * 1024,
    );
    defer allocator.free(slurp);

    const doc = try yaml.Value.fromString(allocator, slurp);
    defer doc.deinit();

    std.debug.print("\n-----\n\n", .{});

    dump(doc.root);
}

fn dump(val: yaml.Value) void {
    switch (val) {
        .scalar => |str| std.debug.print("scalar: {s}\n", .{str}),
        .list => |list| {
            std.debug.print("list: \n", .{});
            for (list) |item| dump(item);
            std.debug.print("end list\n", .{});
        },
        .map => |map| {
            std.debug.print("map: \n", .{});
            var iter = map.iterator();
            while (iter.next()) |entry| {
                std.debug.print("key: {s}\n", .{entry.key_ptr.*});
                dump(entry.value_ptr.*);
            }
            std.debug.print("end map\n", .{});
        },
    }
}
