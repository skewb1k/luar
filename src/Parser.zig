const Parser = @This();

const std = @import("std");
const Ast = @import("Ast.zig");
const Tokenizer = @import("Tokenizer.zig");

allocator: std.mem.Allocator,
tokens: []Tokenizer.Token,
pos: usize,

fn init(allocator: std.mem.Allocator, tokens: []Tokenizer.Token) Parser {
    return .{
        .allocator = allocator,
        .tokens = tokens,
        .pos = 0,
    };
}

fn parseRoot(parser: *Parser) !Ast {
    const rootBlock = try parser.parseBlock();
    return .{
        .arena = undefined,
        .root = rootBlock,
    };
}

fn parseBlock(parser: *Parser) ![]Ast.Statement {
    var statements: std.ArrayList(Ast.Statement) = .empty;

    while (parser.currentToken().tag != .eof) {
        const statement = try parser.parseStatement();
        try statements.append(parser.allocator, statement);
    }

    return try statements.toOwnedSlice(parser.allocator);
}

fn parseStatement(parser: *Parser) !Ast.Statement {
    // Only parse assignments for now.
    const lhs = try parser.parseExpression();
    _ = try parser.expectToken(.equal);
    const rhs = try parser.parseExpression();

    return .{
        .Assignment = .{
            .lhs = lhs,
            .rhs = rhs,
        },
    };
}

fn parseExpression(parser: *Parser) !*Ast.Expression {
    return parser.parseBinaryExpression(1);
}

fn parseBinaryExpression(parser: *Parser, min_prec: u8) !*Ast.Expression {
    var left_operand = try parser.parsePrimaryExpression();

    while (true) {
        const operator = parser.currentToken();
        const prec = binary_precedence.get(operator.tag);
        if (prec == 0 or prec < min_prec) {
            break;
        }
        parser.pos += 1;

        const right_operand = try parser.parseBinaryExpression(prec + 1);

        left_operand = try parser.allocExpression(.{
            .Binary = .{
                .left_operand = left_operand,
                .operator = operator,
                .right_operand = right_operand,
            },
        });
    }

    return left_operand;
}

// TODO: consider factoring out error set.
fn parsePrimaryExpression(parser: *Parser) error{ ParseError, OutOfMemory }!*Ast.Expression {
    const token = parser.currentToken();
    switch (token.tag) {
        .identifier,
        .number_literal,
        .string_literal,
        .keyword_nil,
        .keyword_true,
        .keyword_false,
        => {
            parser.pos += 1;
            return try parser.allocExpression(.{
                .Basic = token,
            });
        },
        .paren_left => {
            parser.pos += 1;
            const expression = try parser.parseExpression();
            _ = try parser.expectToken(.paren_right);
            return try parser.allocExpression(.{
                .Parenthesized = .{
                    .expression = expression,
                },
            });
        },
        else => {
            // TODO: add proper error handling.
            std.debug.print("parseExpression: unexpected tag: {}\n", .{token.tag});
            return error.ParseError;
        },
    }
}

const binary_precedence = std.EnumArray(Tokenizer.Token.Tag, u8).initDefault(0, .{
    .keyword_or = 1,
    .keyword_and = 2,
    .angle_bracket_left = 3,
    .angle_bracket_left_equal = 3,
    .angle_bracket_right = 3,
    .angle_bracket_right_equal = 3,
    .tilde_equal = 3,
    .equal_equal = 3,
    .ellipsis2 = 4,
    .plus = 5,
    .minus = 5,
    .asterisk = 6,
    .slash = 6,
    .percent = 6,
    .caret = 7,
});

fn allocExpression(parser: *Parser, expression: Ast.Expression) error{OutOfMemory}!*Ast.Expression {
    const ptr = try parser.allocator.create(Ast.Expression);
    ptr.* = expression;
    return ptr;
}

fn currentToken(parser: *Parser) Tokenizer.Token {
    return parser.tokens[parser.pos];
}

fn expectToken(parser: *Parser, tag: Tokenizer.Token.Tag) !Tokenizer.Token {
    const token = parser.currentToken();
    if (token.tag != tag) {
        return error.ParseError;
    }
    parser.pos += 1;
    return token;
}

pub fn parse(allocator: std.mem.Allocator, source: [:0]const u8) !Ast {
    var tokens: std.ArrayList(Tokenizer.Token) = .empty;
    defer tokens.deinit(allocator);

    var tokenizer: Tokenizer = .init(source);
    while (true) {
        const token = tokenizer.next();
        try tokens.append(allocator, token);
        if (token.tag == .eof) {
            break;
        }
    }

    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();

    var parser: Parser = .init(arena.allocator(), tokens.allocatedSlice());
    var tree = try parser.parseRoot();
    tree.arena = arena;
    return tree;
}

test "parse" {
    var tree = try parse(std.testing.allocator, "a = 1");
    defer tree.deinit();
}
