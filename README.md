# Zig Text Templates

This project implements a template generator for Zig that works similar to how PHP works.

It allows you to mix plain text and Zig code to generate automatic text files.

Consider the following example:

```zig
<#
// This tag let's you import global statements available to the `render()` function
const std = @import("std");
#>

# Zig Text Template

The following syntax inserts `ctx.intro` formattet with the format string `{s:-^10}`.

<= ctx.intro : {s:-^10} =>

The list has the following <= ctx.list.len => items:

<? for(ctx.list) |item| { ?>
    - <= item.name : {s} => *(weight <= item.weight : {d:.1} => kg)*
<? } ?>

You can pass arbitrary format strings and expressions to the direct formatter:
- <= "hello:world" : {s} =>
- <= (10 + 20 * 30) =>
- <= std.math.log10(10 + 20 * 30) =>

Note that for using a `:` inside the format expression itself, use braces to encapsulate the items.

```

This was inspired by both [PHP](https://www.php.net/manual/en/intro-whatis.php) and [Microsofts T4](https://docs.microsoft.com/en-us/visualstudio/modeling/code-generation-and-t4-text-templates?view=vs-2019) engine.

## Usage

Each generated template will yield a `zig` file which exports a function called `render`:
```zig
pub fn render(stream: anytype, ctx: anytype) !void {
  …
}
```

This function must be invoked with a `std.io.Writer` for the first argument and *any* value for the second argument. `ctx` is meant to pass information from the caller to the template engine to allow dynamic content generation.

To generate templates in your build script, just run the executable with `FileSource`s.

```zig
< TO BE DONE >
```

For a full example, see `build.zig` and the `example` folder.

## Syntax

The syntax knows these constructs:

- `<? … ?>` will paste everything between the start and end sigil verbatim into the `render` function code. This can be used to generate loops, conditions, ...
- `<= expr => will print a default-formatted (`{}`) expression into the stream.
- `<= expr : format =>` will behave similar to the default-formatted version, but you can specify your own format string in `format`. This accepts any format string that `std.fmt.format` accepts for the type of `expr`.
- `<# … #>` will paste everything between the start and end sigil verbatim into the global scope of the Zig code. This can be used to create custom functions or exports.

Note that both `<# … #>` and `<? … ?>` will swallow a directly following line break, while `<= … =>` will not. This makes writing templates more intuitive.