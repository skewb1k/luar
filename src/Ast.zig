const Ast = @This();

const std = @import("std");
const Tokenizer = @import("Tokenizer.zig");

arena: std.heap.ArenaAllocator,
source: [:0]const u8,
root: []Statement,

pub fn deinit(tree: *Ast) void {
    tree.arena.deinit();
}

pub const Statement = union(enum) {
    Assignment: struct {
        // TODO: support multiple assignments.
        lhs: *Expression,
        rhs: *Expression,
    },
};

pub const Expression = union(enum) {
    Basic: Tokenizer.Token,
    Parenthesized: struct {
        expression: *Expression,
    },
    Binary: struct {
        left_operand: *Expression,
        operator: Tokenizer.Token,
        right_operand: *Expression,
    },
    // TODO: add other nodes.
};
