const std = @import("std");

const yaml = @import("yaml");

pub fn main() !void {
    if (yaml.loadString("[1,2,3]"))
        std.debug.print("its a list\n", .{});
}
