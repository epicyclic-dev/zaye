pub const libyaml = struct {
    pub const Encoding = enum(c_int) {
        any,
        utf8,
        utf16le,
        utf16be,
    };

    pub const VersionDirective = extern struct {
        major: c_int,
        minor: c_int,
    };

    pub const TagDirective = extern struct {
        handle: ?[*:0]u8,
        prefix: ?[*:0]u8,
    };

    pub const LineBreak = enum(c_int) {
        any,
        cr,
        lf,
        crlf,
    };

    pub const ErrorType = enum(c_int) {
        okay,
        alloc_error,
        read_error,
        scanner_error,
        parser_error,
        composer_error,
        writer_error,
        emitter_error,
    };

    pub const Mark = extern struct {
        index: usize,
        line: usize,
        column: usize,
    };

    pub const ScalarStyle = enum(c_int) {
        any,
        plain,
        single_quoted,
        double_quoted,
        literal,
        folded,
    };

    pub const SequenceStyle = enum(c_int) {
        any,
        block,
        flow,
    };

    pub const MappingStyle = enum(c_int) {
        any,
        block,
        flow,
    };

    pub const TokenType = enum(c_int) {
        none,
        stream_start,
        stream_end,
        version_directive,
        tag_directive,
        document_start,
        document_end,
        block_sequence_start,
        block_mapping_start,
        block_end,
        flow_sequence_start,
        flow_sequence_end,
        flow_mapping_start,
        flow_mapping_end,
        block_entry,
        flow_entry,
        key,
        value,
        alias,
        anchor,
        tag,
        scalar,
    };

    pub const Token = extern struct {
        type: TokenType,
        data: extern union {
            stream_start: extern struct {
                encoding: Encoding,
            },
            alias: extern struct {
                value: ?[*:0]u8,
            },
            anchor: extern struct {
                value: ?[*:0]u8,
            },
            tag: extern struct {
                handle: ?[*:0]u8,
                suffix: ?[*:0]u8,
            },
            scalar: extern struct {
                value: [*]u8,
                length: usize,
                style: ScalarStyle,
            },
            version_directive: VersionDirective,
            tag_directive: TagDirective,
        },
        start_mark: Mark,
        end_mark: Mark,
    };

    pub const EventType = enum(c_int) {
        empty,
        stream_start,
        stream_end,
        document_start,
        document_end,
        alias,
        scalar,
        sequence_start,
        sequence_end,
        mapping_start,
        mapping_end,
    };

    pub const Event = extern struct {
        type: EventType,
        data: extern union {
            stream_start: extern struct {
                encoding: Encoding,
            },
            document_start: extern struct {
                version_directive: ?*VersionDirective,
                tag_directives: extern struct {
                    start: ?*TagDirective,
                    end: ?*TagDirective,
                },
                implicit: c_int,
            },
            document_end: extern struct { implicit: c_int },
            alias: extern struct { anchor: [*:0]u8 },
            scalar: extern struct {
                anchor: ?[*:0]u8,
                tag: ?[*:0]u8,
                value: [*]u8,
                length: usize,
                plain_implicit: c_int,
                quoted_implicit: c_int,
                style: ScalarStyle,
            },
            sequence_start: extern struct {
                anchor: ?[*:0]u8,
                tag: ?[*:0]u8,
                implicit: c_int,
                style: SequenceStyle,
            },
            mapping_start: extern struct {
                anchor: ?[*:0]u8,
                tag: ?[*:0]u8,
                implicit: c_int,
                style: MappingStyle,
            },
        },
        start_mark: Mark,
        end_mark: Mark,

        pub fn deinit(self: *Event) void {
            yaml_event_delete(self);
        }

        pub extern fn yaml_event_delete(event: *Event) void;
    };

    pub const SimpleKey = extern struct {
        possible: c_int,
        required: c_int,
        token_number: usize,
        mark: Mark,
    };

    pub const NodeType = enum(c_int) {
        none,
        scalar,
        sequence,
        mapping,
    };

    pub const NodeItem = c_int;

    pub const NodePair = extern struct {
        key: c_int,
        value: c_int,
    };

    pub const Node = extern struct {
        type: NodeType,
        tag: ?[*:0]u8,
        data: extern union {
            scalar: extern struct {
                value: ?[*:0]u8,
                length: usize,
                style: ScalarStyle,
            },
            sequence: extern struct {
                items: extern struct {
                    start: ?*NodeItem,
                    end: ?*NodeItem,
                    top: ?*NodeItem,
                },
                style: SequenceStyle,
            },
            mapping: extern struct {
                pairs: extern struct {
                    start: ?*NodePair,
                    end: ?*NodePair,
                    top: ?*NodePair,
                },
                style: MappingStyle,
            },
        },
        start_mark: Mark,
        end_mark: Mark,
    };

    pub const Document = extern struct {
        nodes: extern struct {
            start: ?*Node,
            end: ?*Node,
            top: ?*Node,
        },
        version_directive: ?*VersionDirective,
        tag_directives: extern struct {
            start: ?*TagDirective,
            end: ?*TagDirective,
        },
        start_implicit: c_int,
        end_implicit: c_int,
        start_mark: Mark,
        end_mark: Mark,
    };

    pub const AliasData = extern struct {
        anchor: ?[*]u8,
        index: c_int,
        mark: Mark,
    };

    pub const ReadHandler = *const fn (ctx: ?*anyopaque, buffer: [*]u8, buffer_size: usize, bytes_read: *usize) callconv(.C) c_int;

    pub const ParserState = enum(c_int) {
        stream_start,
        implicit_document_start,
        document_start,
        document_content,
        document_end,
        block_node,
        block_node_or_indentless_sequence,
        flow_node,
        block_sequence_first_entry,
        block_sequence_entry,
        indentless_sequence_entry,
        block_mapping_first_key,
        block_mapping_key,
        block_mapping_value,
        flow_sequence_first_entry,
        flow_sequence_entry,
        flow_sequence_entry_mapping_key,
        flow_sequence_entry_mapping_value,
        flow_sequence_entry_mapping_end,
        flow_mapping_first_key,
        flow_mapping_key,
        flow_mapping_value,
        flow_mapping_empty_value,
        end,
    };

    pub const Parser = extern struct {
        @"error": ErrorType,
        problem: ?[*:0]const u8,
        problem_offset: usize,
        problem_value: c_int,
        problem_mark: Mark,
        context: ?[*:0]const u8,
        context_mark: Mark,
        read_handler: ?ReadHandler,
        read_handler_data: ?*anyopaque,
        input: extern union {
            string: extern struct {
                start: ?[*]const u8,
                end: ?[*]const u8,
                current: ?[*]const u8,
            },
            file: ?*anyopaque,
        },
        eof: c_int,
        buffer: extern struct {
            start: ?[*]u8,
            end: ?[*]u8,
            pointer: ?[*]u8,
            last: ?[*]u8,
        },
        unread: usize,
        raw_buffer: extern struct {
            start: ?[*]u8,
            end: ?[*]u8,
            pointer: ?[*]u8,
            last: ?[*]u8,
        },
        encoding: Encoding,
        offset: usize,
        mark: Mark,
        stream_start_produced: c_int,
        stream_end_produced: c_int,
        flow_level: c_int,
        tokens: extern struct {
            start: ?*Token,
            end: ?*Token,
            head: ?*Token,
            tail: ?*Token,
        },
        tokens_parsed: usize,
        token_available: c_int,
        indents: extern struct {
            start: ?*c_int,
            end: ?*c_int,
            top: ?*c_int,
        },
        indent: c_int,
        simple_key_allowed: c_int,
        simple_keys: extern struct {
            start: ?*SimpleKey,
            end: ?*SimpleKey,
            top: ?*SimpleKey,
        },
        states: extern struct {
            start: ?*SimpleKey,
            end: ?*SimpleKey,
            top: ?*SimpleKey,
        },
        state: ParserState,
        marks: extern struct {
            start: ?*Mark,
            end: ?*Mark,
            top: ?*Mark,
        },
        tag_directives: extern struct {
            start: ?*TagDirective,
            end: ?*TagDirective,
            top: ?*TagDirective,
        },
        aliases: extern struct {
            start: ?*AliasData,
            end: ?*AliasData,
            top: ?*AliasData,
        },
        document: ?*Document,

        pub fn init() !Parser {
            var parser: Parser = undefined;
            if (yaml_parser_initialize(&parser) == 0) return error.Failed;
            return parser;
        }

        pub fn deinit(self: *Parser) void {
            yaml_parser_delete(self);
        }

        pub fn setInputString(self: *Parser, input: []const u8) void {
            yaml_parser_set_input_string(self, input.ptr, input.len);
        }

        pub fn parse(self: *Parser, event: *Event) !void {
            if (yaml_parser_parse(self, event) == 0) return error.Failed;
        }

        pub extern fn yaml_parser_initialize(parser: *Parser) c_int;
        pub extern fn yaml_parser_delete(parser: *Parser) void;
        pub extern fn yaml_parser_set_input_string(parser: *Parser, input: [*]const u8, size: usize) void;
        pub extern fn yaml_parser_set_input(parser: *Parser, handler: ReadHandler, data: ?*anyopaque) void;
        pub extern fn yaml_parser_set_encoding(parser: *Parser, encoding: Encoding) void;
        pub extern fn yaml_parser_scan(parser: *Parser, token: *Token) c_int;
        pub extern fn yaml_parser_parse(parser: *Parser, event: *Event) c_int;
        pub extern fn yaml_parser_load(parser: *Parser, document: *Document) c_int;
    };
};

const std = @import("std");

pub fn loadString(data: []const u8) bool {
    // return api.load_string(data.ptr, data.len);

    var parser = libyaml.Parser.init() catch {
        std.debug.print("noinit\n", .{});
        return false;
    };
    defer parser.deinit();

    parser.setInputString(data);

    var done = false;
    while (!done) {
        var event: libyaml.Event = undefined;
        parser.parse(&event) catch {
            std.debug.print("noparse\n", .{});
            return false;
        };
        defer event.deinit();

        std.debug.print("event: {s}\n", .{@tagName(event.type)});

        done = event.type == .stream_end;
    }
    return true;
}
