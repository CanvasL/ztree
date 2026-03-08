const std = @import("std");
const ztree = @import("ztree");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var path: []const u8 = ".";
    var showHidden = false;
    var dirsOnly = false;
    var maxDepth: ?usize = null;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            std.debug.print(
                \\Usage: ztree [OPTIONS] [PATH]
                \\
                \\  PATH          Directory to list (default: .)
                \\
                \\Options:
                \\  -a            Show hidden files and directories
                \\  -d            List directories only
                \\  -L=<N>        Limit depth of directory tree to N levels
                \\  -h, --help    Show this help message
                \\
            , .{});
            return;
        } else if (std.mem.eql(u8, arg, "-a")) {
            showHidden = true;
        } else if (std.mem.eql(u8, arg, "-d")) {
            dirsOnly = true;
        } else if (std.mem.startsWith(u8, arg, "-L=")) {
            maxDepth = try std.fmt.parseInt(usize, arg[3..], 10);
        } else {
            path = arg;
        }
    }

    var root = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer root.close();

    std.debug.print("{s}\n", .{path});
    try ztree.printTree(root, "", allocator, showHidden, dirsOnly, maxDepth, 0);
}
