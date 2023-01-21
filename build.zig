const std = @import("std");

const TemplateStep = @import("src/TemplateStep.zig");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const template_step = TemplateStep.createSource(b, std.build.FileSource{
        .path = "example/layout.ztt",
    });

    const exe = b.addExecutable("demo", "example/main.zig");
    exe.addPackage(std.build.Pkg{
        .name = "template",
        .source = template_step.getFileSource(),
    });
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the demo");
    run_step.dependOn(&run_cmd.step);
}
