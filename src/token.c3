module ebnf;

import std::io;

struct Position
{
	String filename;
	usz row, col, offset;
}

fn sz? Position.to_format(&self, Formatter* f) @dynamic
{
	sz len = f.printf(
		"(Position){.filename = %s,.row = %d," +++ ".col = %d,.offset = %d}",
		self.filename,
		self.row,
		self.col,
		self.offset
	)!;
	return len;
}

enum TokenType
{
	EOF,
	COMMENT,

	LPAREN,
	RPAREN,
	DOT,
	EQUAL,
	LSBRACKET,
	RSBRACKET,
	LBRACKET,
	RBRACKET,
	BAR,

	// with lexeme:
	TERMINAL,
	NON_TERMINAL,
}

struct Token
{
	TokenType type;
	Position pos;
	String lexeme;
}

fn sz? Token.to_format(&self, Formatter* f) @dynamic
{
	sz len = f.printf("(Token){.type = %s,", self.type)!;
	len += self.pos.to_format(f)!;
	len += f.printf(", .lexeme = %s}", self.lexeme)!;
	return len;
}
