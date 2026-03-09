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
    const stdout = std.fs.File.stdout();
    var buf: [8192]u8 = undefined;
    var fw = stdout.writer(&buf);
    const w = &fw.interface;
    const tty = std.io.tty.Config.detect(stdout);

    var numDirs: usize = 0;
    var numFiles: usize = 0;
    try printTreeInner(dir, prefix, allocator, showHidden, dirsOnly, maxDepth, currentDepth, &numDirs, &numFiles, w, tty);
    try w.print("\n{d} {s}, {d} {s}\n", .{
        numDirs,  if (numDirs == 1) "directory" else "directories",
        numFiles, if (numFiles == 1) "file" else "files",
    });
    try w.flush();
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
    w: *std.io.Writer,
    tty: std.io.tty.Config,
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
            try w.print("{s}{s}", .{ prefix, marker });
            try setEntryColor(tty, w, entry.kind);
            try w.print("{s}", .{entry.name});
            try tty.setColor(w, .reset);
            try w.print("\n", .{});
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

            try printTreeInner(subdir, newPrefix, allocator, showHidden, dirsOnly, maxDepth, currentDepth + 1, numDirs, numFiles, w, tty);
        } else {
            numFiles.* += 1;
        }
    }
}

fn setEntryColor(tty: std.io.tty.Config, w: *std.io.Writer, kind: std.fs.File.Kind) !void {
    switch (kind) {
        .file => {
            try tty.setColor(w, .green);
        },
        .directory => {
            try tty.setColor(w, .cyan);
        },
        .sym_link => {
            try tty.setColor(w, .magenta);
        },
        .named_pipe => {
            try tty.setColor(w, .yellow);
        },
        .unix_domain_socket => {
            try tty.setColor(w, .red);
        },
        else => {},
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
