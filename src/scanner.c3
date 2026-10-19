module ebnf;

import std::collections;
import std::core::ascii;
import std::io;
import std::os;

// Scanner owns tokens.
<*
  EBNF Scanner struct.
*>
struct Scanner
{
  Allocator allocator;
  Position pos;
  usz i, j;
  String source;
  List{Token} tokens;
}

<*
  Initializes the Scanner struct.
*>
fn void scanner_init(Scanner *scanner,
		     Allocator allocator,
		     String filename,
		     String source) @private
{
  scanner.allocator = allocator;
  scanner.tokens.init(allocator);
  scanner.pos.filename = filename;
  scanner.source = source;  
}

<*
  Frees the associated data of the tokens.
*>
fn void scanner_free(Scanner *scanner) @inline @private
{
  scanner.tokens.free();
}

<*
  Scans the tokens from the input string.
*>
fn bool scanner_scan(Scanner *scanner,ParseError *err) @private
{
  while(true) {
    Token t = scanner_scan_token(scanner).@or_else(;it) {
      *err = it.error;
      return false;
    };
    scanner.tokens.push(t);
    if(t.type == EOF) break;
  }
  return true;
}

<*
  Scans and returns one Token.
*>
fn Result{Token,ParseError} scanner_scan_token(Scanner *scanner)
{
  scanner_skip(scanner);
  scanner.i = scanner.j;
  if(scanner_is_at_end(scanner))
  {
    return result::ok((Token){.type = EOF,.pos = scanner.pos});
  }
  char c = scanner_advance(scanner);
  switch(c)
  {
    case '(':
      if (scanner_match(scanner, '*'))
      {
	ParseError err;
	if (!scanner_skip_comments(scanner, &err))
	{
	  return result::err(err);
	}
	return scanner_scan_token(scanner);
      }
      return result::ok((Token){.type = LPAREN,
	.pos = scanner.pos, .lexeme = "("});
    case ')':
      return result::ok((Token){.type = RPAREN,
	.pos = scanner.pos,
	.lexeme = ")"});
    case '.':
      return result::ok((Token){.type = DOT,
	.pos = scanner.pos,
	.lexeme = "."});
    case '=':
      return result::ok((Token){.type = EQUAL,
	.pos = scanner.pos,
	.lexeme = "="});
    case '[':
      return result::ok((Token){.type = LSBRACKET,
	.pos = scanner.pos,
	.lexeme = "["});
    case ']':
      return result::ok((Token){.type = RSBRACKET,
	.pos = scanner.pos,
	.lexeme = "]"});
    case '{':
      return result::ok((Token){.type = LBRACKET,
	.pos = scanner.pos,
	.lexeme = "{"});
    case '}':
      return result::ok((Token){.type = RBRACKET,
	.pos = scanner.pos,
	.lexeme = "}"});
    case '|':
      return result::ok((Token){.type = BAR,
	.pos = scanner.pos,
	.lexeme = "|"});
    case '"':
    case '\'':
      return scanner_scan_terminal(scanner,c);
    default:
      if(is_identifier_char(c))
      {
	return scanner_scan_non_terminal(scanner);
      }
      return result::err((ParseError){.pos = scanner.pos,
	.msg = string::tformat("Unexpected character: '%c'",c)});
  }
}

<*
 Skips (possibly nested) comments.
*>
fn bool scanner_skip_comments(Scanner *scanner,
			      ParseError *err) @private
{
  sz level = 1;
  while(!scanner_is_at_end(scanner) && level > 0)
  {
    char c = scanner_peek(scanner);
    switch(c)
    {
      case '\n':
	scanner_advance(scanner);
	scanner_add_line(scanner);
      case '(':
	scanner_advance(scanner);
	if(scanner_match(scanner,'*')) level++;
      case '*':
	scanner_advance(scanner);
	if(scanner_match(scanner,')')) level--;
      default:
	scanner_advance(scanner);
    }
  }

  if(level != 0)
  {
    *err = (ParseError){.pos = scanner.pos,
      .msg = "Unterminated comment"};
    return false;
  }
  scanner.i = scanner.j;
  return true;
}

<*
  Skips whitespace characters.
*>
fn void scanner_skip(Scanner *scanner)
{
  while(!scanner_is_at_end(scanner) &&
	ascii::is_space(scanner_peek(scanner)))
  {
    char c = scanner_advance(scanner);
    if(c == '\n') scanner_add_line(scanner);
  }
  scanner.i = scanner.j;
}

<*
  Scans a terminal Token.
*>
fn Result{Token,ParseError} scanner_scan_terminal(Scanner *scanner,
						  char end) @private
{
  while(!scanner_is_at_end(scanner) && scanner_peek(scanner) != end)
  {
    scanner_advance(scanner);
  }
  if(scanner_is_at_end(scanner))
  {
    return result::err((ParseError){.pos = scanner.pos,
      .msg = "Unterminated terminal"});
  }

  defer
  {
    scanner_advance(scanner);
    scanner.i = scanner.j;
  }

  return result::ok((Token){.type = TERMINAL,.pos = scanner.pos,
    .lexeme = scanner.source[scanner.i + 1:scanner.j - scanner.i - 1]});
}

<*
  Scans a non-terminal Token.
*>
fn Result{Token,ParseError}
scanner_scan_non_terminal(Scanner *scanner) @private
{
  while(!scanner_is_at_end(scanner) &&
	is_identifier_char(scanner_peek(scanner)))
  {
    scanner_advance(scanner);
  }
  defer scanner.i = scanner.j;
  return result::ok((Token){.type = NON_TERMINAL,
    .pos = scanner.pos,
    .lexeme = scanner.source[scanner.i..scanner.j-1]});
}

<*
  Checks if scanner is at the end.
*>
fn bool scanner_is_at_end(Scanner *scanner) @inline @private
{
  return scanner.j >= scanner.source.len;
}

<*
  Returns the current character of the Scanner.
*>
fn char scanner_peek(Scanner *scanner) @private
{
  if(scanner_is_at_end(scanner)) return '\0';
  return scanner.source[scanner.j];
}

<*
 Checks and advances by a character if that character is equal the
 expected character.
*>
fn bool scanner_match(Scanner *scanner,
		      char expected) @inline @private
{
  if(scanner_peek(scanner) == expected)
  {
    scanner_advance(scanner);
    return true;
  }
  return false;
}

<*
 Advances the scanner by one character.
*>
fn char scanner_advance(Scanner *scanner) @private
{
  if(scanner_is_at_end(scanner)) return '\0';
  scanner.pos.col++;
  scanner.pos.offset++;
  return scanner.source[scanner.j++];
}

<*
 Adds a newline to the Scanner's Position.
*>
fn void scanner_add_line(Scanner *scanner) @private
{
  scanner.pos.row++;
  scanner.pos.col = 0;
  scanner.pos.offset++;
}

<*
 Checks if a character is valid in an identifier.
*>
fn bool is_identifier_char(char c) @inline @private
{
  return ascii::is_alnum(c) || c == '_';
}

