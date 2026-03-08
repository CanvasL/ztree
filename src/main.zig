const std = @import("std");
const ztree = @import("ztree");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const path = if (args.len > 1) args[1] else ".";

    var cwd = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer cwd.close();

    std.debug.print("{s}\n", .{path});

    try printTree(cwd, "");
}

pub fn printTree(dir: std.fs.Dir, prefix: []const u8) !void {
    var it = dir.iterate();

    while (try it.next()) |entry| {
        std.debug.print("{s}├── {s}\n", .{ prefix, entry.name });

        if (entry.kind == .directory) {
            var subdir = try dir.openDir(entry.name, .{ .iterate = true });
            defer subdir.close();

            var buf: [256]u8 = undefined;
            const newPrefix = try std.fmt.bufPrint(&buf, "{s}│   ", .{prefix});

            try printTree(subdir, newPrefix);
        }
    }
}
