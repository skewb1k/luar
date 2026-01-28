const std = @import("std");

pub fn main() void {
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
}

test {
    _ = @import("Formatter.zig");
    _ = @import("Parser.zig");
    _ = @import("Tokenizer.zig");
}
