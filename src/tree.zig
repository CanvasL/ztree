const std = @import("std");
const Allocator = std.mem.Allocator;
const Entry = @import("entry.zig").Entry;
const lessThan = @import("entry.zig").lessThan;

pub fn printTree(
    dir: std.fs.Dir,
    prefix: []const u8,
    allocator: Allocator,
    showHidden: bool,
    dirsOnly: bool,
    maxDepth: ?usize,
    currentDepth: usize,
) !void {
    var numDirs: usize = 0;
    var numFiles: usize = 0;
    try printTreeInner(dir, prefix, allocator, showHidden, dirsOnly, maxDepth, currentDepth, &numDirs, &numFiles);
    std.debug.print("\n{d} {s}, {d} {s}\n", .{
        numDirs,  if (numDirs == 1) "directory" else "directories",
        numFiles, if (numFiles == 1) "file" else "files",
    });
}

fn printTreeInner(
    dir: std.fs.Dir,
    prefix: []const u8,
    allocator: Allocator,
    showHidden: bool,
    dirsOnly: bool,
    maxDepth: ?usize,
    currentDepth: usize,
    numDirs: *usize,
    numFiles: *usize,
) !void {
    if (maxDepth != null and maxDepth.? <= currentDepth) return;

    var entries = try listDir(dir, allocator, showHidden);
    defer {
        for (entries.items) |e| allocator.free(e.name);
        entries.deinit(allocator);
    }

    const len = entries.items.len;

    for (entries.items, 0..) |entry, index| {
        const isLast = index == len - 1;
        const marker = if (isLast) "└── " else "├── ";

        if (!dirsOnly or entry.kind == .directory) {
            std.debug.print("{s}{s}{s}\n", .{ prefix, marker, entry.name });
        }

        if (entry.kind == .directory) {
            numDirs.* += 1;
            var subdir = dir.openDir(entry.name, .{ .iterate = true }) catch continue;
            defer subdir.close();

            var buf: [256]u8 = undefined;
            const newPrefix =
                if (isLast)
                    try std.fmt.bufPrint(&buf, "{s}    ", .{prefix})
                else
                    try std.fmt.bufPrint(&buf, "{s}│   ", .{prefix});

            try printTreeInner(subdir, newPrefix, allocator, showHidden, dirsOnly, maxDepth, currentDepth + 1, numDirs, numFiles);
        } else {
            numFiles.* += 1;
        }
    }
}

fn listDir(dir: std.fs.Dir, allocator: Allocator, showHidden: bool) !std.ArrayListUnmanaged(Entry) {
    var entries: std.ArrayListUnmanaged(Entry) = .empty;
    var it = dir.iterate();
    while (try it.next()) |e| {
        if (!showHidden and e.name[0] == '.') continue;
        try entries.append(allocator, Entry{ .name = try allocator.dupe(u8, e.name), .kind = e.kind });
    }
    std.mem.sort(Entry, entries.items, {}, lessThan);
    return entries;
}
