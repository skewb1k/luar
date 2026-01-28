const Formatter = @This();

const std = @import("std");
const Ast = @import("Ast.zig");
const Parser = @import("Parser.zig");
const Tokenizer = @import("Tokenizer.zig");

w: *std.Io.Writer,
tree: Ast,

fn init(w: *std.Io.Writer, tree: Ast) Formatter {
    return .{
        .w = w,
        .tree = tree,
    };
}

fn formatTree(formatter: *Formatter) !void {
    try formatter.formatBlock(formatter.tree.root);
}

fn formatBlock(formatter: *Formatter, block: []Ast.Statement) !void {
    for (block, 0..) |statement, i| {
        if (i != 0) {
            try formatter.w.writeAll("\n");
        }
        try formatter.formatStatement(statement);
    }
}

fn formatStatement(formatter: *Formatter, statement: Ast.Statement) !void {
    switch (statement) {
        .Assignment => |assignment| {
            try formatter.formatExpression(assignment.lhs.*);
            try formatter.w.writeAll(" = ");
            try formatter.formatExpression(assignment.rhs.*);
        },
    }
}

fn formatExpression(formatter: *Formatter, expression: Ast.Expression) !void {
    switch (expression) {
        .Basic => |token| {
            try formatter.w.writeAll(formatter.tokenContent(token));
        },
        .Parenthesized => |parenthesized_expression| {
            try formatter.w.writeByte('(');
            try formatter.formatExpression(parenthesized_expression.expression.*);
            try formatter.w.writeByte(')');
        },
        .Binary => |binary_expression| {
            try formatter.formatExpression(binary_expression.left_operand.*);
            try formatter.w.writeByte(' ');
            try formatter.w.writeAll(formatter.tokenContent(binary_expression.operator));
            try formatter.w.writeByte(' ');
            try formatter.formatExpression(binary_expression.right_operand.*);
        },
    }
}

fn tokenContent(formatter: *Formatter, token: Tokenizer.Token) []const u8 {
    return formatter.tree.source[token.location.start..token.location.end];
}

pub fn format(tree: Ast, w: *std.Io.Writer) !void {
    var formatter: Formatter = .init(w, tree);
    try formatter.formatTree();
}

test "statements" {
    try testStable(
        \\a = true
    );
}

test "expressions" {
    try testStable(
        \\_ = 1 + 2
        \\_ = 1 + 2 * 2
        \\_ = (1 + 2) * 2
    );
}

fn testStable(source: [:0]const u8) !void {
    try testFormat(source, source);
}

fn testFormat(source: [:0]const u8, expected_source: []const u8) !void {
    var tree: Ast = try Parser.parse(std.testing.allocator, source);
    defer tree.deinit();

    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();

    try format(tree, &output.writer);
    try std.testing.expectEqualStrings(expected_source, output.written());
}
