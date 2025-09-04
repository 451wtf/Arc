const std = @import("std");
const TokenType = @import("tokens.zig").TokenType;
const Token = @import("tokens.zig").Token;
const Allocator = std.mem.Allocator;

const keywords = std.StaticStringMap(TokenType).initComptime(.{
    .{ "const", .kw_const },
    .{ "let", .kw_let },
    .{ "var", .kw_var },
    .{ "if", .kw_if },
    .{ "else", .kw_else },
    .{ "while", .kw_while },
    .{ "for", .kw_for },
    .{ "return", .kw_return },
    .{ "fun", .kw_fun },
    .{ "process", .kw_process },
    .{ "message", .kw_message },
    .{ "impl", .impl },
    .{ "spawn", .kw_spawn },
    .{ "bool", .kw_bool },
    .{ "self", .identifier },
    .{ "import", .kw_import },
    .{ "as", .kw_as },
    .{ "in", .kw_in },
    .{ "struct", .kw_struct },
    .{ "enum", .kw_enum },
    .{ "union", .kw_union },
    .{ "trait", .kw_trait },
    .{ "match", .kw_match },
    .{ "mut", .kw_mut },
    .{ "str8", .kw_str },
    .{ "strA", .kw_strA },
    .{ "str16", .kw_str16 },
    .{ "str32", .kw_str32 },
    .{ "stringA", .kw_stringA },
    .{ "string", .kw_string },
    .{ "string16", .kw_string16 },
    .{ "string32", .kw_string32 },
    .{ "generic", .kw_generic },
    .{ "typealias", .kw_typealias },
    .{ "true", .lit_bool },
    .{ "false", .lit_bool },
});

const Lexer = struct {
    input: []const u8,
    position: usize, // Index of input str
    line: usize, // line of code
    column: usize, // char in line

    fn init(input: []const u8) Lexer {
        return Lexer{
            .input = input,
            .position = 0,
            .line = 1,
            .column = 1,
        };
    }

    fn current(self: Lexer) ?u8 {
        if (self.position < self.input.len) {
            return self.input[self.position];
        }
        return null;
    }

    fn advance(self: *Lexer) ?u8 {
        if (self.position >= self.input.len) return null;

        const ch = self.input[self.position];
        self.position += 1;

        if (ch == '\n') {
            self.line += 1;
            self.column = 1;
        } else {
            self.column += 1;
        }

        return ch;
    }

    fn skip_whitespace(self: *Lexer) void {
        while (self.current()) |ch| {
            if (std.ascii.isWhitespace(ch)) {
                _ = self.advance();
            } else {
                break;
            }
        }
    }

    fn make_token(self: Lexer, token_type: TokenType, start_pos: usize) Token {
        return Token{
            .type = token_type,
            .text = self.input[start_pos..self.position], // Zero-copy slice!
            .line = self.line,
            .column = self.column,
        };
    }

    fn read_number(self: *Lexer) Token {
        const start_pos = self.position;
        var has_dot = false;

        while (self.current()) |ch| {
            if (std.ascii.isDigit(ch)) {
                _ = self.advance();
            } else if (ch == '.' and !has_dot) {
                // Check if this is a range operator (.. or ...) rather than a decimal point
                if (self.position + 1 < self.input.len and self.input[self.position + 1] == '.') {
                    // This is a range operator, don't consume the dot
                    break;
                }
                // Check if next character after dot is a digit (valid float)
                if (self.position + 1 < self.input.len and std.ascii.isDigit(self.input[self.position + 1])) {
                    has_dot = true;
                    _ = self.advance();
                } else {
                    // Not a valid float, stop parsing
                    break;
                }
            } else {
                break;
            }
        }

        return self.make_token(if (has_dot) .lit_float else .lit_int, start_pos);
    }

    fn read_identifier(self: *Lexer) Token {
        const start_pos = self.position;
        while (self.current()) |ch| {
            if (std.ascii.isAlphanumeric(ch) or ch == '_') {
                _ = self.advance();
            } else {
                break;
            }
        }
        const text = self.input[start_pos..self.position];
        return self.make_token(keywords.get(text) orelse .identifier, start_pos);
    }

    fn next_token(self: *Lexer) Token {
        self.skip_whitespace();

        const start_pos = self.position;
        const start_line = self.line;
        const start_column = self.column;

        const ch = self.current() orelse {
            return Token{
                .type = .eof,
                .text = "",
                .line = start_line,
                .column = start_column,
            };
        };

        switch (ch) {
            // Single character tokens
            '(' => {
                _ = self.advance();
                return self.make_token(.left_paren, start_pos);
            },
            ')' => {
                _ = self.advance();
                return self.make_token(.right_paren, start_pos);
            },
            '{' => {
                _ = self.advance();
                return self.make_token(.left_brace, start_pos);
            },
            '}' => {
                _ = self.advance();
                return self.make_token(.right_brace, start_pos);
            },
            '[' => {
                _ = self.advance();
                return self.make_token(.left_bracket, start_pos);
            },
            ']' => {
                _ = self.advance();
                return self.make_token(.right_bracket, start_pos);
            },
            ';' => {
                _ = self.advance();
                return self.make_token(.semicolon, start_pos);
            },
            ',' => {
                _ = self.advance();
                return self.make_token(.comma, start_pos);
            },
            '+' => {
                _ = self.advance();
                return self.make_token(.plus, start_pos);
            },
            '-' => {
                _ = self.advance();
                if (self.current() == '>') {
                    _ = self.advance();
                    return self.make_token(.arrow, start_pos);
                }
                return self.make_token(.minus, start_pos);
            },
            '*' => {
                _ = self.advance();
                if (self.current() == '*') {
                    _ = self.advance();
                    return self.make_token(.power, start_pos);
                }
                return self.make_token(.multiply, start_pos);
            },
            '%' => {
                _ = self.advance();
                return self.make_token(.modulo, start_pos);
            },
            '/' => {
                _ = self.advance();
                if (self.current() == '/') {
                    // Single line comment
                    while (self.current()) |comment_ch| {
                        if (comment_ch == '\n') break;
                        _ = self.advance();
                    }
                    return self.next_token(); // Skip comment and get next token
                }
                return self.make_token(.divide, start_pos);
            },
            '=' => {
                _ = self.advance();
                if (self.current() == '=') {
                    _ = self.advance();
                    return self.make_token(.equal, start_pos);
                } else if (self.current() == '>') {
                    _ = self.advance();
                    return self.make_token(.arrow, start_pos);
                }
                return self.make_token(.assign, start_pos);
            },
            '>' => {
                _ = self.advance();
                if (self.current() == '=') {
                    _ = self.advance();
                    return self.make_token(.greater_equal, start_pos);
                }
                return self.make_token(.greater, start_pos);
            },
            '<' => {
                _ = self.advance();
                if (self.current() == '=') {
                    _ = self.advance();
                    return self.make_token(.less_equal, start_pos);
                }
                return self.make_token(.less, start_pos);
            },
            ':' => {
                _ = self.advance();
                if (self.current() == ':') {
                    _ = self.advance();
                    return self.make_token(.double_colon, start_pos);
                }
                return self.make_token(.colon, start_pos);
            },
            '$' => {
                _ = self.advance();
                return self.make_token(.dollar, start_pos);
            },
            '^' => {
                _ = self.advance();
                return self.make_token(.caret, start_pos);
            },
            '.' => {
                _ = self.advance();
                if (self.current() == '.') {
                    _ = self.advance();
                    if (self.current() == '.') {
                        _ = self.advance();
                        return self.make_token(.incl_range, start_pos); // ...
                    } else {
                        return self.make_token(.excl_range, start_pos); // ..
                    }
                }
                return self.make_token(.dot, start_pos);
            },
            '&' => {
                _ = self.advance();
                return self.make_token(.ampersand, start_pos);
            },
            '"' => {
                _ = self.advance();
                // Read until closing quote
                while (self.current()) |quote_ch| {
                    if (quote_ch == '"') {
                        _ = self.advance();
                        break;
                    } else if (quote_ch == '\\') {
                        _ = self.advance(); // Skip escape
                        _ = self.advance(); // Skip escaped char
                    } else {
                        _ = self.advance();
                    }
                }
                return self.make_token(.lit_str, start_pos);
            },
            '!' => {
                _ = self.advance();
                if (self.current() == '=') {
                    _ = self.advance();
                    return self.make_token(.not_equal, start_pos);
                }
                return self.make_token(.exclamation, start_pos);
            },
            '|' => {
                _ = self.advance();
                if (self.current() == '>') {
                    _ = self.advance();
                    return self.make_token(.piping, start_pos);
                }
                return self.make_token(.pipe, start_pos);
            },

            // Multi-character tokens
            '0'...'9' => return self.read_number(),
            'a'...'z', 'A'...'Z', '_' => return self.read_identifier(),

            // Unknown character (including UTF-8)
            else => {
                // Skip UTF-8 continuation bytes
                if (ch >= 0x80) {
                    // This is a UTF-8 multi-byte character, skip all bytes
                    _ = self.advance();
                    while (self.current()) |utf8_ch| {
                        if (utf8_ch < 0x80 or utf8_ch >= 0xC0) break;
                        _ = self.advance();
                    }
                    return Token{
                        .type = .unknown,
                        .text = self.input[start_pos..self.position],
                        .line = start_line,
                        .column = start_column,
                    };
                } else {
                    _ = self.advance();
                    return Token{
                        .type = .Error,
                        .text = self.input[start_pos..self.position],
                        .line = start_line,
                        .column = start_column,
                    };
                }
            },
        }
    }
};

pub fn tokenize(allocator: Allocator, input: []const u8) ![]Token {
    var lexer = Lexer.init(input);
    var tokens = std.ArrayList(Token).init(allocator);

    try tokens.ensureTotalCapacity(32);

    while (true) {
        const token = lexer.next_token();

        // Always add the token (even EOF)
        try tokens.append(token);

        // Stop when we reach EOF
        if (token.type == .eof) {
            break;
        }
    }

    return tokens.toOwnedSlice();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Read from example.txt
    const source = try std.fs.cwd().readFileAlloc(allocator, "src/lexer/example.txt", 1024 * 1024);
    defer allocator.free(source);

    // Tokenize
    const tokens = try tokenize(allocator, source);
    defer allocator.free(tokens);

    // Write to tokens.txt
    const file = try std.fs.cwd().createFile("src/lexer/tokens.txt", .{});
    defer file.close();

    const writer = file.writer();
    for (tokens) |token| {
        try writer.print("Token: {s} ({s}) at line {d}, col {d}\n", .{ @tagName(token.type), token.text, token.line, token.column });
    }
}
