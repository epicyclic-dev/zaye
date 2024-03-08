const std = @import("std");

pub const libyaml = @import("./libyaml.zig");

pub const Scalar = []const u8;
pub const List = []Value;
pub const Map = std.StringArrayHashMapUnmanaged(Value);

pub const ParseDiagnostic = struct {
    message: []const u8,
    line: usize = 0,
    col: usize = 0,

    pub fn set(self: *ParseDiagnostic, mark: libyaml.Mark, message: []const u8) void {
        self.line = mark.line + 1;
        self.col = mark.column;
        self.message = message;
    }

    pub fn setMark(self: *ParseDiagnostic, mark: libyaml.Mark) void {
        self.line = mark.line + 1;
        self.col = mark.column;
    }

    pub fn setMessage(self: *ParseDiagnostic, message: []const u8) void {
        self.message = message;
    }
};

pub const Document = struct {
    root: Value,
    allocator: *std.heap.ArenaAllocator,

    pub fn fromString(allocator: std.mem.Allocator, data: []const u8, diag: *ParseDiagnostic) !Document {
        var parser = libyaml.Parser.init() catch {
            diag.setMessage("could not initialize libyaml parser");
            return error.Failed;
        };
        defer parser.deinit();

        parser.setInputString(data);

        var builder = Value.Builder.init(allocator) catch {
            diag.setMessage("could not initialize value builder: out of memory");
            return error.Failed;
        };
        errdefer builder.deinit();

        var docseen = false;
        while (true) {
            var event: libyaml.Event = undefined;
            parser.parse(&event) catch {
                diag.set(
                    parser.problem_mark,
                    if (parser.problem) |problem|
                        std.mem.span(problem)
                    else
                        "parsing failed without a description",
                );
                return error.Failed;
            };
            defer event.deinit();

            switch (event.type) {
                .empty => {
                    diag.set(event.start_mark, "an empty event was generated (???)");
                    return error.Failed;
                },
                .alias => {
                    diag.set(event.start_mark, "an alias node was encountered (these are not supported)");
                    return error.Failed;
                },
                .document_start => {
                    if (docseen) {
                        diag.set(event.start_mark, "A second YAML document was found");
                        return error.Failed;
                    }
                    docseen = true;
                },
                .scalar => builder.pushScalar(event.data.scalar.value[0..event.data.scalar.length], diag) catch {
                    diag.setMark(event.start_mark);
                    return error.Failed;
                },
                .sequence_start => builder.startList(diag) catch {
                    diag.setMark(event.start_mark);
                    return error.Failed;
                },
                .sequence_end => builder.endList(diag) catch {
                    diag.setMark(event.start_mark);
                    return error.Failed;
                },
                .mapping_start => builder.startMap(diag) catch {
                    diag.setMark(event.start_mark);
                    return error.Failed;
                },
                .mapping_end => builder.endMap(diag) catch {
                    diag.setMark(event.start_mark);
                    return error.Failed;
                },
                .stream_start, .document_end => {},
                .stream_end => break,
            }
        }

        return builder.document() catch {
            diag.setMessage("The value builder container stack is not empty, somehow?");
            return error.Failed;
        };
    }

    pub fn deinit(self: Document) void {
        const child = self.allocator.child_allocator;
        self.allocator.deinit();
        child.destroy(self.allocator);
    }
};

pub const Value = union(enum) {
    scalar: Scalar,
    list: List,
    map: Map,

    pub const Builder = struct {
        pub const Stack = union(enum) {
            root,
            list: std.ArrayListUnmanaged(Value),
            map: struct {
                lastkey: ?Scalar = null,
                map: Map,
            },
        };

        allocator: std.mem.Allocator,
        container_stack: std.ArrayListUnmanaged(Stack),
        root: Value,

        pub fn init(child_allocator: std.mem.Allocator) std.mem.Allocator.Error!Builder {
            const arena = try child_allocator.create(std.heap.ArenaAllocator);
            arena.* = std.heap.ArenaAllocator.init(child_allocator);
            const allocator = arena.allocator();

            var stack = try std.ArrayListUnmanaged(Stack).initCapacity(allocator, 1);
            stack.appendAssumeCapacity(.root);

            return .{
                .allocator = allocator,
                .container_stack = stack,
                .root = .{ .scalar = "" },
            };
        }

        // this should only be run on failure.
        pub fn deinit(self: Builder) void {
            const arena: *std.heap.ArenaAllocator = @ptrCast(@alignCast(self.allocator.ptr));
            const alloc = arena.child_allocator;
            arena.deinit();
            alloc.destroy(arena);
        }

        pub fn document(self: *Builder) !Document {
            if (self.container_stack.getLast() != .root)
                return error.Failed;

            return .{
                .root = self.root,
                .allocator = @ptrCast(@alignCast(self.allocator.ptr)),
            };
        }

        fn pushScalar(self: *Builder, value: Scalar, diag: *ParseDiagnostic) !void {
            switch (self.container_stack.items[self.container_stack.items.len - 1]) {
                .root => {
                    self.root = .{ .scalar = try self.allocator.dupe(u8, value) };
                },
                .list => |*builder| builder.append(self.allocator, .{
                    .scalar = self.allocator.dupe(u8, value) catch {
                        diag.setMessage("could not duplicate scalar (out of memory)");
                        return error.Failed;
                    },
                }) catch {
                    diag.setMessage("could not append scalar to list (out of memory)");
                    return error.Failed;
                },
                .map => |*builder| {
                    if (builder.lastkey) |key| {
                        builder.map.put(self.allocator, key, .{
                            .scalar = self.allocator.dupe(u8, value) catch {
                                diag.setMessage("could not duplicate scalar (out of memory)");
                                return error.Failed;
                            },
                        }) catch {
                            diag.setMessage("could not set map value (out of memory)");
                            return error.Failed;
                        };
                        builder.lastkey = null;
                    } else {
                        const duped = self.allocator.dupe(u8, value) catch {
                            diag.setMessage("could not duplicate scalar (out of memory)");
                            return error.Failed;
                        };
                        builder.map.put(self.allocator, duped, undefined) catch {
                            diag.setMessage("could not set map key (out of memory)");
                            return error.Failed;
                        };
                        builder.lastkey = duped;
                    }
                },
            }
        }

        fn startList(self: *Builder, diag: *ParseDiagnostic) !void {
            self.container_stack.append(self.allocator, .{ .list = .{} }) catch {
                diag.setMessage("could not add list to stack: out of memory");
                return error.Failed;
            };
        }

        fn endList(self: *Builder, diag: *ParseDiagnostic) !void {
            var top = self.container_stack.pop();
            if (top != .list) {
                diag.setMessage("list ended when a list was not the top container");
                return error.Failed;
            }

            switch (self.container_stack.items[self.container_stack.items.len - 1]) {
                .root => self.root = .{
                    .list = top.list.toOwnedSlice(self.allocator) catch {
                        diag.setMessage("could not take ownership of list");
                        return error.Failed;
                    },
                },
                .list => |*builder| builder.append(self.allocator, .{
                    .list = top.list.toOwnedSlice(self.allocator) catch {
                        diag.setMessage("could not take ownership of list");
                        return error.Failed;
                    },
                }) catch {
                    diag.setMessage("could not append list to list");
                    return error.Failed;
                },
                .map => |*builder| {
                    if (builder.lastkey) |key| {
                        builder.map.put(self.allocator, key, .{
                            .list = top.list.toOwnedSlice(self.allocator) catch {
                                diag.setMessage("could not take ownership of list");
                                return error.Failed;
                            },
                        }) catch {
                            diag.setMessage("could not put list in map");
                            return error.Failed;
                        };
                        builder.lastkey = null;
                    } else {
                        diag.setMessage("found a list masquerading as a map key (only scalar keys are supported)");
                        return error.Failed;
                    }
                },
            }
        }

        fn startMap(self: *Builder, diag: *ParseDiagnostic) !void {
            self.container_stack.append(self.allocator, .{ .map = .{ .map = .{} } }) catch {
                diag.setMessage("could not add map to stack: out of memory");
                return error.Failed;
            };
        }

        fn endMap(self: *Builder, diag: *ParseDiagnostic) !void {
            var top = self.container_stack.pop();

            if (top != .map) {
                diag.setMessage("map ended when a map was not the top container");
                return error.Failed;
            }

            switch (self.container_stack.items[self.container_stack.items.len - 1]) {
                .root => self.root = .{ .map = top.map.map },
                .list => |*builder| builder.append(
                    self.allocator,
                    .{ .map = top.map.map },
                ) catch {
                    diag.setMessage("could not append map to list");
                    return error.Failed;
                },
                .map => |*builder| {
                    if (builder.lastkey) |key| {
                        builder.map.put(self.allocator, key, .{ .map = top.map.map }) catch {
                            diag.setMessage("could not put map in map");
                            return error.Failed;
                        };
                        builder.lastkey = null;
                    } else {
                        diag.setMessage("found a map masquerading as a map key (only scalar keys are supported)");
                        return error.Failed;
                    }
                },
            }
        }
    };

    pub fn jsonStringify(value: @This(), jws: anytype) !void {
        switch (value) {
            .scalar => |scalar| try jws.write(scalar),
            .list => |list| try jws.write(list),
            .map => |map| {
                try jws.beginObject();
                var it = map.iterator();
                while (it.next()) |entry| {
                    try jws.objectField(entry.key_ptr.*);
                    try jws.write(entry.value_ptr.*);
                }
                try jws.endObject();
            },
        }
    }
};
