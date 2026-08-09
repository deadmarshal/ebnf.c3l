module ebnf;

import std::collections;
import std::core::ascii;
import std::io;
import std::os;

alias ScannerResult = Result{List{Token}, ScannerError};

struct ScannerError
{
	Position pos;
	String msg;
}

struct Scanner
{
	Allocator allocator;
	Position pos;
	usz i, j;
	String source;
	List{Token} tokens;
}

fn void Scanner.init(&self, Allocator allocator, String filename, String source)
{
	self.allocator = allocator;
	self.tokens.init(allocator);
	self.pos.filename = filename;
	self.source = source;
}

fn void Scanner.free(&self)
{
	self.tokens.free();
}

fn ScannerResult Scanner.scan(&self)
{
	while (!self.isAtEnd())
	{
		self.i = self.j;
		Token t = self.scan_token().@or_else(; it)
		{
      return result::err(it.error);
		};
    self.tokens.push(t);
	}
	return result::ok(self.tokens);
}

fn Result{Token, ScannerError} Scanner.scan_token(&self)
{
	self.skip();

	if (self.isAtEnd())
	{
		return result::ok((Token) { .type = EOF, .pos = self.pos });
	}

	char c = self.advance();

	switch (c)
	{
		case '(':
			return result::ok((Token) { .type = LPAREN, .pos = self.pos, .lexeme = "(" });
		case ')':
			return result::ok((Token) { .type = RPAREN, .pos = self.pos, .lexeme = ")" });
		case '.':
			return result::ok((Token) { .type = DOT, .pos = self.pos, .lexeme = "." });
		case '=':
			return result::ok((Token) { .type = EQUAL, .pos = self.pos, .lexeme = "=" });
		case '[':
			return result::ok((Token) { .type = LSBRACKET, .pos = self.pos, .lexeme = "[" });
		case ']':
			return result::ok((Token) { .type = RSBRACKET, .pos = self.pos, .lexeme = "]" });
		case '{':
			return result::ok((Token) { .type = LBRACKET, .pos = self.pos, .lexeme = "{" });
		case '}':
			return result::ok((Token) { .type = RBRACKET, .pos = self.pos, .lexeme = "}" });
		case '|':
			return result::ok((Token) { .type = BAR, .pos = self.pos, .lexeme = "|" });
		case '"':
			return self.scanTerminal(c);
		default:
			if (ascii::is_alpha(c))
			{
				return self.scanNonTerminal();
			}
			else
			{
				return result::err(
					(ScannerError) { .pos = self.pos, .msg = string::format(tmem, "Unexpected character: '%c'", c), }
				);
			}
	}
}

// Private:
fn void Scanner.skip(&self)
{
	while (!self.isAtEnd() && ascii::is_space(self.peek()))
	{
		if (self.peek() == '\n') self.addLine();
		self.advance();
	}
}

fn Result{Token, ScannerError} Scanner.scanTerminal(&self, char end)
{
	while (!self.isAtEnd() && self.peek() != end) self.advance();
	if (self.isAtEnd()) return result::err((ScannerError) { .pos = self.pos, .msg = "Unterminated terminal.", });

	defer
	{
		self.advance();
		self.i = self.j;
	}

	return result::ok((Token) { .type = TERMINAL, .pos = self.pos, .lexeme = self.source[self.i + 1..self.j], });
}

fn Result{Token, ScannerError} Scanner.scanNonTerminal(&self)
{
	while (!self.isAtEnd() && ascii::is_alpha(self.peek())) self.advance();
	defer self.i = self.j;

	return result::ok((Token) { .type = NON_TERMINAL, .pos = self.pos, .lexeme = self.source[self.i..self.j - 1], });
}

fn bool Scanner.isAtEnd(self) @inline
{
	return self.j >= self.source.len;
}

fn char Scanner.peek(self)
{
	if (self.isAtEnd()) return '\0';
	return self.source[self.j];
}

fn char Scanner.advance(&self)
{
	if (self.isAtEnd()) return '\0';
	self.pos.col++;
	self.pos.offset++;
	return self.source[self.j++];
}

fn void Scanner.addLine(&self)
{
	self.pos.row++;
	self.pos.col = 0;
	self.pos.offset++;
}
