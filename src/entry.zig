const std = @import("std");

pub const Entry = struct {
    name: []const u8,
    kind: std.fs.File.Kind,
};

pub fn lessThan(_: void, a: Entry, b: Entry) bool {
    return std.mem.order(u8, a.name, b.name) == .lt;
}
