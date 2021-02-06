# Zig Text Templates

**NOTE: This project depends on [PR #7959](https://github.com/ziglang/zig/pull/7959) of the Zig project.**

This project implements a custom build step that generates text template executors. A template in this case is text file that can embed zig code to generate dynamic content. A small example:

```zig
# <? try output.writeAll(context.title); ?>

## Contents
<? for(context.chapters) |chapter, i| { ?>
- <? try output.print("{}. {s}", .{ i+1, chapter.title }); ?><? } ?>

<? for(context.chapters) |chapter| { ?>
## <? try output.writeAll(chapter.title); try output.writeAll("\n");

try output.writeAll(chapter.content);
try output.writeAll("\n");
} ?>
```

This was inspired by both [PHP](https://www.php.net/manual/en/intro-whatis.php) and [Microsofts T4](https://docs.microsoft.com/en-us/visualstudio/modeling/code-generation-and-t4-text-templates?view=vs-2019) engine.

## Usage

Each generated template will yield a `zig` file which exports a single function:
```zig
pub fn render(output: anytype, context: anytype) !void {
  …
}
```

This function must be invoked with a `std.io.Writer` for the first argument and *any* value for the second argument. `context` is meant to pass information from the caller to the template engine to allow dynamic content generation.

To generate a template, a custom `std.build.Step` is provided in `src/TemplateStep.zig`. Use it like this:

```zig
const std = @import("std");

const TemplateStep = @import("src/TemplateStep.zig");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const template_step = TemplateStep.create(b, std.build.FileSource{
        .path = "example/layout.ztt",
    });

    const exe = b.addExecutable("demo", "example/main.zig");
    exe.addPackage(std.build.Pkg{
        .name = "template",
        .path = template_step.getFileSource(),
    });
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();
}
```

For a full example, see `build.zig` and the `example` folder.

## Syntax

The syntax is very simple right now. Text is copied verbatim into the `output` stream until a `<?` is found. After this, code will be copied into the zig file until a `?>` is discovered.

### Planned extensions:

```
<?= some.value ?>
```
will invoke `try output.print("{}", .{ some.value })` so values can be printed  inline easily.

A formatting option might be passed into it as well:
```
<?{d:0>8} some.int ?>
```
will invoke `try output.print("{d:0>8}", .{ some.int })`.