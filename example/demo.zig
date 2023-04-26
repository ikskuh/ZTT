const std = @import("std");
const template = @import("demo-ztt");

pub fn main() !void {
    var stdout = std.io.getStdOut();

    const Item = struct {
        name: [:0]const u8,
        weight: f32,
    };

    try template.render(stdout.writer(), .{
        .intro = "This is an introduction to the Zig Text Template system!",
        .list = [_]Item{
            .{ .name = "Flour", .weight = 0.5 },
            .{ .name = "Bottle of water", .weight = 1.1 },
        },
    });
}
