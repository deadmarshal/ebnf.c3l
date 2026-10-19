module ebnf;

import std::io;

<*
  Position of a token in the file.
*>
struct Position(Printable)
{
  String filename;
  usz row, col, offset;
}

fn sz? Position.to_format(&self, Formatter* f) @dynamic
{
  sz len = f.printf(
    "(Position){.filename = %s,.row = %d," +++
    ".col = %d,.offset = %d}",
    self.filename,
    self.row,
    self.col,
    self.offset
  )!;
  return len;
}

<*
  Type of a token.
*>
enum TokenType
{
  EOF,

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

// Token owns nothing, lexeme is slices off of the original string
// so the caller frees the source string.
<*
  A scanner Token.
*>
struct Token(Printable)
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

