const std = @import("std");

pub fn main() !void {
    const argv = try std.process.argsAlloc(std.heap.c_allocator);
    defer std.process.argsFree(std.heap.c_allocator, argv);

    if (argv.len != 3)
        @panic("usage: template-renderer <input> <output>");

    const source = try std.fs.cwd().readFileAlloc(std.heap.c_allocator, argv[1], 1 << 30);
    defer std.heap.c_allocator.free(source);

    var out_file = try std.fs.cwd().createFile(argv[2], .{});
    defer out_file.close();

    try renderToStream(std.heap.c_allocator, source, out_file.writer());
}

fn isOpeningBrace(char: u8) bool {
    return (char == '(') or (char == '[');
}

fn isClosingBrace(char: u8) bool {
    return (char == ')') or (char == ']');
}

fn scanStream(source: []const u8, pos_ptr: *usize, end_marker: u8, consume_line_break: bool) error{UnbalancedParenthesis}!?[]const u8 {
    const original_pos = pos_ptr.*;
    var pos = pos_ptr.*;

    var balance: usize = 0;

    while (pos < source.len) {
        if (balance == 0 and pos > original_pos and source[pos] == '>' and source[pos - 1] == end_marker) {
            const end_pos = pos - 1;

            if (consume_line_break and pos + 1 < source.len and source[pos + 1] == '\n') {
                pos_ptr.* = pos + 2;
            } else {
                pos_ptr.* = pos + 1;
            }
            return std.mem.trim(u8, source[original_pos + 1 .. end_pos], " \t\r\n");
        } else {
            if (isOpeningBrace(source[pos])) {
                balance += 1;
            }
            if (isClosingBrace(source[pos])) {
                if (balance == 0)
                    return error.UnbalancedParenthesis;
                balance -= 1;
            }
            pos += 1;
        }
    }

    return null;
}

const FormatArgs = struct {
    expression: []const u8,
    fmt_string: ?[]const u8,
};

fn scanFormatExpr(source: []const u8) !FormatArgs {
    var balance: usize = 0;
    var in_string: bool = false;

    var pos: usize = 0;
    while (pos < source.len) : (pos += 1) {
        const char = source[pos];

        if (in_string and char == '"' and (pos == 0 or source[pos - 1] != '\\')) {
            in_string = false;
        } else if (in_string) {
            // we're not doing anything here
        } else if (isOpeningBrace(char)) {
            balance += 1;
        } else if (isClosingBrace(char)) {
            if (balance == 0)
                return error.UnbalancedParenthesis;
            balance -= 1;
        } else if (char == '"') {
            in_string = true;
        } else if (balance == 0 and char == ':') {
            return FormatArgs{
                .expression = std.mem.trim(u8, source[0..pos], " \t\r\n"),
                .fmt_string = std.mem.trim(u8, source[pos + 1 ..], " \t\r\n"),
            };
        }
    }
    return FormatArgs{
        .expression = std.mem.trim(u8, source, " \t\r\n"),
        .fmt_string = null,
    };
}

fn renderToStream(maybe_allocator: ?std.mem.Allocator, source: []const u8, stream: anytype) !void {
    var buffered_out = std.io.bufferedWriter(stream);

    const BufferedStream = @TypeOf(buffered_out);

    const OutStream = struct {
        const Self = @This();

        stream: BufferedStream.Writer,

        fn emitRaw(emitter: Self, str: []const u8) !void {
            try emitter.stream.writeAll(str);
        }

        fn emitRawFormatted(emitter: Self, comptime str: []const u8, fmt: anytype) !void {
            try emitter.stream.print(str, fmt);
        }

        fn emitPlainText(emitter: Self, str: []const u8) !void {
            if (str.len == 0)
                return;
            try emitter.stream.print("    try stream.writeAll(\"{}\");\n", .{std.zig.fmtEscapes(str)});
        }
    };

    const output = OutStream{
        .stream = buffered_out.writer(),
    };

    try output.emitRaw(
        \\pub fn render(stream: anytype, ctx: anytype) !void {
        \\  // beware of this dirty hack for pseudo-unused
        \\  {
        \\      const  ___magic = .{ stream, ctx };
        \\      _ = ___magic;
        \\  }
        \\  // here comes the actual content
        \\
    );

    var global_scope = std.ArrayListUnmanaged(u8){};
    defer if (maybe_allocator) |alloc| {
        global_scope.deinit(alloc);
    };

    var pos: usize = 0;
    while (pos < source.len) {
        const pos_or_null = std.mem.indexOfScalarPos(u8, source, pos, '<');

        if (pos_or_null) |new_pos| {
            try output.emitPlainText(source[pos..new_pos]);
            pos = new_pos + 1;

            if (new_pos + 1 < source.len) {
                const item = source[new_pos + 1];
                switch (item) {
                    '#', '=', '?' => {
                        const content = (try scanStream(source, &pos, item, (item != '='))) orelse {
                            try output.emitPlainText(&.{ '<', item });
                            pos += 1;
                            continue;
                        };

                        // std.debug.print("--- PARSE RESULT ---\n{s}\n----\n", .{content});
                        switch (item) {
                            '#' => {
                                const allocator = maybe_allocator orelse return error.GlobalScopeRequiresAllocator;

                                try global_scope.append(allocator, '\n');
                                try global_scope.appendSlice(allocator, content);
                                try global_scope.append(allocator, '\n');
                            },
                            '=' => {
                                const fmt = try scanFormatExpr(content);

                                try output.emitRawFormatted("    try stream.print(\"{}\", .{{", .{std.zig.fmtEscapes(fmt.fmt_string orelse "{}")});
                                try output.emitRaw(fmt.expression);
                                try output.emitRaw("});\n");
                            },
                            '?' => {
                                try output.emitRaw(content);
                                try output.emitRaw("\n");
                            },
                            else => unreachable,
                        }
                    },
                    else => {
                        try output.emitPlainText(&.{ '<', item });

                        pos = new_pos + 2;
                    },
                }
            }
        } else {
            // flush the rest
            try output.emitPlainText(source[pos..]);
            pos = source.len;
        }
    }

    try output.emitRaw(
        \\}
        \\
    );

    try output.emitRaw(global_scope.items);

    try buffered_out.flush();
}
