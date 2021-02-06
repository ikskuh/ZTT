const std = @import("std");

const Book = struct {
    title: []const u8,
    chapters: []const Chapter,
};

const Chapter = struct {
    title: []const u8,
    content: []const u8,
};

pub fn main() anyerror!void {
    var book = Book{
        .title = "The Book Of Souls",
        .chapters = &[_]Chapter{
            Chapter{
                .title = "Birth",
                .content = "First, you get born!",
            },
            Chapter{
                .title = "Live",
                .content = "Then, you live your life day by day.",
            },
            Chapter{
                .title = "Death",
                .content = "But in the end, you die!",
            },
        },
    };

    try @import("template").render(
        std.io.getStdOut().writer(),
        book,
    );
}
