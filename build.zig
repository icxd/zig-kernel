const std = @import("std");
const Feature = std.Target.Cpu.Feature;

pub fn build(b: *std.Build) void {
    var disabled_features = Feature.Set.empty;
    var enabled_features = Feature.Set.empty;

    disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.mmx));
    disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.sse));
    disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.sse2));
    disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.avx));
    disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.avx2));
    enabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.soft_float));

    const target = b.standardTargetOptions(.{ .default_target = .{ .cpu_arch = .x86, .os_tag = .freestanding, .abi = .none, .cpu_features_sub = disabled_features, .cpu_features_add = enabled_features } });
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "kernel",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.code_model = .kernel;
    exe.setLinkerScriptPath(.{ .path = "linker.ld" });
    exe.pie = true;

    b.installArtifact(exe);

    const kernel_step = b.step("kernel", "Build the kernel");
    kernel_step.dependOn(&exe.step);

    const kernel_path = b.getInstallPath(.bin, exe.name);

    const iso_dir = b.fmt("{s}/iso_root", .{b.cache_root.path.?});
    const iso_path = b.fmt("{s}/disk.iso", .{b.exe_dir});

    const iso_cmd_str = &[_][]const u8{ "/bin/sh", "-c", std.mem.concat(b.allocator, u8, &[_][]const u8{ "mkdir -p ", iso_dir, " && ", "cp ", kernel_path, " ", iso_dir, " && ", "cp grub.cfg ", iso_dir, " && ", "grub-mkrescue -o ", iso_path, " ", iso_dir }) catch unreachable };

    const iso_cmd = b.addSystemCommand(iso_cmd_str);
    iso_cmd.step.dependOn(kernel_step);

    const iso_step = b.step("iso", "Build an ISO image");
    iso_step.dependOn(&iso_cmd.step);
    b.default_step.dependOn(iso_step);

    const run_cmd_str = &[_][]const u8{ "qemu-system-x86_64", "-cdrom", b.fmt("{s}/disk.iso", .{b.exe_dir}), "-debugcon", "stdio", "-vga", "virtio", "-m", "4G", "-machine", "q35,accel=kvm:whpx:tcg", "-no-reboot", "-no-shutdown" };

    const run_cmd = b.addSystemCommand(run_cmd_str);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the kernel");
    run_step.dependOn(&run_cmd.step);
}
