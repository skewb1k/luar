//! Lua 5.1 tokenizer.
//! https://www.lua.org/manual/5.1/manual.html#2.1
//!
//! The implementation is heavily inspired by the Zig language tokenizer (MIT licensed):
//! https://codeberg.org/ziglang/zig/src/commit/3729a53eec1951376c01c7e799b439b1a84694b5/lib/std/zig/tokenizer.zig
const Tokenizer = @This();

const std = @import("std");

buffer: [:0]const u8,
index: usize,

pub fn init(buffer: [:0]const u8) Tokenizer {
    // TODO: skip the UTF-8 BOM if present.
    return .{
        .buffer = buffer,
        .index = 0,
    };
}

pub fn next(self: *Tokenizer) Token {
    var result: Token = .{
        .tag = undefined,
        .location = .{
            .start = self.index,
            .end = undefined,
        },
    };
    state: switch (State.start) {
        .start => switch (self.buffer[self.index]) {
            0 => {
                if (self.index == self.buffer.len) {
                    return .{
                        .tag = .eof,
                        .location = .{
                            .start = self.index,
                            .end = self.index,
                        },
                    };
                } else {
                    continue :state .invalid;
                }
            },
            ' ', '\n', '\t', '\r' => {
                self.index += 1;
                result.location.start = self.index;
                continue :state .start;
            },
            '"', '\'' => {
                result.tag = .string_literal;
                continue :state .string_literal;
            },
            'a'...'z', 'A'...'Z', '_' => {
                result.tag = .identifier;
                continue :state .identifier;
            },
            '0'...'9' => {
                result.tag = .number_literal;
                continue :state .int;
            },
            '^' => {
                result.tag = .caret;
                self.index += 1;
            },
            ':' => {
                result.tag = .colon;
                self.index += 1;
            },
            ',' => {
                result.tag = .comma;
                self.index += 1;
            },
            '(' => {
                result.tag = .paren_left;
                self.index += 1;
            },
            ')' => {
                result.tag = .paren_right;
                self.index += 1;
            },
            '{' => {
                result.tag = .brace_left;
                self.index += 1;
            },
            '}' => {
                result.tag = .brace_right;
                self.index += 1;
            },
            '[' => {
                result.tag = .bracket_left;
                self.index += 1;
            },
            ']' => {
                result.tag = .bracket_right;
                self.index += 1;
            },
            '+' => {
                result.tag = .plus;
                self.index += 1;
            },
            '#' => {
                result.tag = .pound;
                self.index += 1;
            },
            ';' => {
                result.tag = .semicolon;
                self.index += 1;
            },
            '%' => {
                result.tag = .percent;
                self.index += 1;
            },
            '*' => {
                result.tag = .asterisk;
                self.index += 1;
            },
            '/' => {
                result.tag = .slash;
                self.index += 1;
            },
            '<' => continue :state .angle_bracket_left,
            '>' => continue :state .angle_bracket_right,
            '=' => continue :state .equal,
            '-' => continue :state .minus,
            '.' => continue :state .period,
            '~' => continue :state .tilde,
            else => continue :state .invalid,
        },

        .invalid => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                0 => {
                    if (self.index == self.buffer.len) {
                        result.tag = .invalid;
                    } else {
                        continue :state .invalid;
                    }
                },
                '\n' => result.tag = .invalid,
                else => continue :state .invalid,
            }
        },

        .angle_bracket_left => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                '=' => {
                    result.tag = .angle_bracket_left_equal;
                    self.index += 1;
                },
                else => result.tag = .angle_bracket_left,
            }
        },

        .angle_bracket_right => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                '=' => {
                    result.tag = .angle_bracket_right_equal;
                    self.index += 1;
                },
                else => result.tag = .angle_bracket_right,
            }
        },

        .comment => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                0 => {
                    if (self.index != self.buffer.len) {
                        result.tag = .invalid;
                    }
                },
                '\n' => self.index += 1,
                else => continue :state .comment,
            }
        },

        .equal => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                '=' => {
                    result.tag = .equal_equal;
                    self.index += 1;
                },
                else => result.tag = .equal,
            }
        },

        .identifier => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                'a'...'z', 'A'...'Z', '_', '0'...'9' => continue :state .identifier,
                else => {
                    const ident = self.buffer[result.location.start..self.index];
                    if (Token.keywords.get(ident)) |tag| {
                        result.tag = tag;
                    }
                },
            }
        },

        .int => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                '.' => continue :state .int_period,
                '_', '0'...'9' => continue :state .int,
                else => {},
            }
        },

        .int_period => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                '_', '0'...'9' => continue :state .int_period,
                else => {},
            }
        },

        .minus => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                '-' => {
                    result.tag = .comment;
                    continue :state .comment;
                },
                else => result.tag = .minus,
            }
        },

        .period => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                '.' => continue :state .period_2,
                else => result.tag = .period,
            }
        },

        .period_2 => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                '.' => {
                    result.tag = .ellipsis3;
                    self.index += 1;
                },
                else => result.tag = .ellipsis2,
            }
        },

        .string_literal => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                0 => {
                    if (self.index == self.buffer.len) {
                        result.tag = .invalid;
                    } else {
                        continue :state .invalid;
                    }
                },
                '"', '\'' => self.index += 1,
                '\n' => result.tag = .invalid,
                else => continue :state .string_literal,
            }
        },

        .tilde => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                '=' => {
                    result.tag = .tilde_equal;
                    self.index += 1;
                },
                else => result.tag = .invalid,
            }
        },
    }

    result.location.end = self.index;
    return result;
}

const State = enum {
    start,
    invalid,
    angle_bracket_left,
    angle_bracket_right,
    comment,
    equal,
    identifier,
    int,
    int_period,
    minus,
    period,
    period_2,
    string_literal,
    tilde,
};

pub const Token = struct {
    tag: Tag,
    location: Location,

    pub const Location = struct {
        start: usize,
        end: usize,
    };

    pub const Tag = enum {
        invalid,
        eof,

        comment,
        identifier,
        number_literal,
        // TODO: separate tags for single- and double-quoted strings.
        string_literal,

        angle_bracket_left,
        angle_bracket_left_equal,
        angle_bracket_right,
        angle_bracket_right_equal,
        asterisk,
        brace_left,
        brace_right,
        bracket_left,
        bracket_right,
        caret,
        colon,
        comma,
        ellipsis2,
        ellipsis3,
        equal,
        equal_equal,
        minus,
        paren_left,
        paren_right,
        percent,
        period,
        plus,
        pound,
        semicolon,
        slash,
        tilde_equal,

        keyword_and,
        keyword_break,
        keyword_do,
        keyword_else,
        keyword_elseif,
        keyword_end,
        keyword_false,
        keyword_for,
        keyword_function,
        keyword_if,
        keyword_in,
        keyword_local,
        keyword_nil,
        keyword_not,
        keyword_or,
        keyword_repeat,
        keyword_return,
        keyword_then,
        keyword_true,
        keyword_until,
        keyword_while,
    };

    pub const keywords = std.StaticStringMap(Tag).initComptime(.{
        .{ "and", .keyword_and },
        .{ "break", .keyword_break },
        .{ "do", .keyword_do },
        .{ "else", .keyword_else },
        .{ "elseif", .keyword_elseif },
        .{ "end", .keyword_end },
        .{ "false", .keyword_false },
        .{ "for", .keyword_for },
        .{ "function", .keyword_function },
        .{ "if", .keyword_if },
        .{ "in", .keyword_in },
        .{ "local", .keyword_local },
        .{ "nil", .keyword_nil },
        .{ "not", .keyword_not },
        .{ "or", .keyword_or },
        .{ "repeat", .keyword_repeat },
        .{ "return", .keyword_return },
        .{ "then", .keyword_then },
        .{ "true", .keyword_true },
        .{ "until", .keyword_until },
        .{ "while", .keyword_while },
    });
};

test "comments" {
    try testTokenize("--", &.{.comment});
    try testTokenize("--comment local", &.{.comment});
    try testTokenize(
        \\local
        \\--comment
        \\local
    , &.{ .keyword_local, .comment, .keyword_local });
    // TODO: support multiline comments.
    // try testTokenize(
    //     \\--[[
    //     \\multiline comment
    //     \\]]
    // , &.{.comment});
}

test "identifiers" {
    try testTokenize("_my_VAR2", &.{.identifier});
}

test "nil, true and false are keywords" {
    try testTokenize("nil true false", &.{ .keyword_nil, .keyword_true, .keyword_false });
}

test "string literals" {
    try testTokenize(
        \\'single'
    , &.{.string_literal});
    try testTokenize(
        \\"double"
    , &.{.string_literal});
    // TODO: support multiline strings.
    // try testTokenize(
    //     \\'"'
    // , &.{.string_literal});
    // try testTokenize(
    //     \\"'"
    // , &.{.string_literal});
    // try testTokenize(
    //     \\[[multi
    //     \\line]]
    // , &.{.string_literal});
    // try testTokenize(
    //     \\[==[long
    //     \\bracket]==]
    // , &.{.string_literal});
}

// TODO: support string literals escape sequences.
// test "string literals escape sequences" {
//     try testTokenize(
//         \\"\\"
//     , &.{.string_literal});
//     try testTokenize(
//         \\"\n"
//     , &.{.string_literal});
//     try testTokenize(
//         \\"\r"
//     , &.{.string_literal});
//     try testTokenize(
//         \\"\""
//     , &.{.string_literal});
// }

test "newline in string literal" {
    try testTokenize(
        \\'
        \\'
    , &.{ .invalid, .invalid });
    try testTokenize(
        \\"
        \\"
    , &.{ .invalid, .invalid });
}

test "number literals" {
    try testTokenize("3", &.{.number_literal});
    try testTokenize("3.0", &.{.number_literal});
    try testTokenize("3.1416", &.{.number_literal});
    // TODO: support exponents and hexadecimal number literals.
    // try testTokenize("314.16e-2" , &.{.number_literal});
    // try testTokenize("0.31416E1" , &.{.number_literal});
    // try testTokenize("0xff" , &.{.number_literal});
    // try testTokenize("0x56" , &.{.number_literal});
}

test "operators" {
    try testTokenize("<", &.{.angle_bracket_left});
    try testTokenize("<=", &.{.angle_bracket_left_equal});
    try testTokenize(">", &.{.angle_bracket_right});
    try testTokenize(">=", &.{.angle_bracket_right_equal});
    try testTokenize("*", &.{.asterisk});
    try testTokenize("{", &.{.brace_left});
    try testTokenize("}", &.{.brace_right});
    try testTokenize("[", &.{.bracket_left});
    try testTokenize("]", &.{.bracket_right});
    try testTokenize("^", &.{.caret});
    try testTokenize(":", &.{.colon});
    try testTokenize(",", &.{.comma});
    try testTokenize("..", &.{.ellipsis2});
    try testTokenize("...", &.{.ellipsis3});
    try testTokenize("=", &.{.equal});
    try testTokenize("==", &.{.equal_equal});
    try testTokenize("-", &.{.minus});
    try testTokenize("(", &.{.paren_left});
    try testTokenize(")", &.{.paren_right});
    try testTokenize("%", &.{.percent});
    try testTokenize(".", &.{.period});
    try testTokenize("+", &.{.plus});
    try testTokenize("#", &.{.pound});
    try testTokenize(";", &.{.semicolon});
    try testTokenize("/", &.{.slash});
    try testTokenize("~=", &.{.tilde_equal});
}

test "whitespace breaks multi-character operators" {
    try testTokenize("~ =", &.{ .invalid, .equal });
}

fn testTokenize(source: [:0]const u8, expected_token_tags: []const Token.Tag) !void {
    var tokenizer = Tokenizer.init(source);
    for (expected_token_tags) |expected_token_tag| {
        const token = tokenizer.next();
        try std.testing.expectEqual(expected_token_tag, token.tag);
    }

    const last_token = tokenizer.next();
    try std.testing.expectEqual(Token.Tag.eof, last_token.tag);
    try std.testing.expectEqual(source.len, last_token.location.start);
    try std.testing.expectEqual(source.len, last_token.location.end);
}
