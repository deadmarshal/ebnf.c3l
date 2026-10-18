module ebnf;

import std::collections;
import std::io;
import std::os;
import std::core::mem::alloc;

struct ParseError
{
  Position pos;
  String msg;
}

fn sz? ParseError.to_format(&self, Formatter* f) @dynamic
{
  sz len = f.print("(ParseError){.pos = ")!;
  len += self.pos.to_format(f)!;
  len += f.printf(", .msg = %s}", self.msg)!;
  return len;
}

struct Parser
{
  Allocator allocator;
  Position pos;
  sz i;
  Scanner *scanner;
}

// TODO: not returning optional in init would be good!
// instead, returning optional in parse function?
fn void? Parser.init(&self,
		     Allocator allocator,
		     String filename,
		     String source)
{
  // Scanner:
  self.scanner = alloc::new_try(allocator,Scanner)!;
  scanner_init(self.scanner,
	       allocator,
	       filename,
	       source);
  // Parser:
  self.allocator = allocator;
}

fn void Parser.free(&self)
{
  scanner_free(self.scanner);
  alloc::free(self.allocator,self.scanner);
}

fn Result{Ebnf,ParseError} Parser.parse(&self)
{
  ParseError err;
  if(!scanner_scan(self.scanner,&err)) return result::err(err);
  
  Ebnf ebnf;
  ebnf.init(self.allocator);
  while(parser_peek(self).type != EOF)
  {
    Production prod = parse_production(self).@or_else(;it) {
      ebnf.free();
      return result::err(it.error);
    };
    ebnf.productions.push(prod);
  }
  return result::ok(ebnf);
}

// Private:
fn Result{Production, ParseError} parse_production(Parser* p) @local
{
  Production prod;
  Token tok = parser_consume(p,
			     NON_TERMINAL,
			     "Expected nonterminal").@or_else(;it) {
    return result::err(it.error);
  };

  prod.lhs = tok.lexeme.copy(p.allocator);

  parser_consume(p, EQUAL, "Expected equal sign").@or_else(; it)
  {
    prod.free(p.allocator);
    return result::err(it.error);
  };

  prod.rhs = parse_expression(p).@or_else(;it) {
    prod.free(p.allocator);
    return result::err(it.error);
  };

  parser_consume(p,
		 DOT,
		 "Expected '.' after production's rhs").@or_else(; it)
  {
    prod.free(p.allocator);
    return result::err(it.error);
  };

  return result::ok(prod);
}

fn Result{Node, ParseError} parse_expression(Parser* p) @local
{
  List{Node} alternatives;
  alternatives.init(p.allocator);
  alternatives.push(parse_term(p).@or_else(; it) {
    foreach(&n : alternatives) n.free(p.allocator);
    alternatives.free();
    return result::err(it.error);
  });

  while(parser_match(p,BAR))
  {
    alternatives.push(parse_term(p).@or_else(; it) {
      foreach(&n : alternatives) n.free(p.allocator);
      alternatives.free();
      return result::err(it.error);
    });
  }

  if (alternatives.len() == 1)
  {
    Node one = alternatives[0];
    alternatives.free();
    return result::ok(one);
  }

  return result::ok({.type = ALTERNATION,.children = alternatives});
}

fn Result{Node, ParseError} parse_term(Parser* p) @local
{
  List{Node} sequence;
  sequence.init(p.allocator);
  sequence.push(parse_factor(p).@or_else(; it) {
    foreach(&n : sequence) n.free(p.allocator);
    sequence.free();
    return result::err(it.error);
  });

  while(true)
  {
    if (parser_check(p, BAR) ||
	parser_check(p, DOT) ||
	parser_check(p, RPAREN) ||
	parser_check(p, RSBRACKET) ||
	parser_check(p, RBRACKET))
    {
      break;
    }

    sequence.push(parse_factor(p).@or_else(; it) {
      foreach(&n : sequence) n.free(p.allocator);
      sequence.free();
      return result::err(it.error);
    });
  }

  if (sequence.len() == 1)
  {
    Node one = sequence[0];
    sequence.free();
    return result::ok(one);
  }

  return result::ok({.type = SEQUENCE, .children = sequence});
}

fn Result{Node, ParseError} parse_factor(Parser* p) @local
{
  if(parser_match(p,LSBRACKET))
  {
    Node inner = parse_expression(p).@or_else(;it) {
      return result::err(it.error);
    };
    parser_consume(p,RSBRACKET,"expected ']'").@or_else(;it) {
      inner.free(p.allocator);
      return result::err(it.error);
    };
    return result::ok({.type = OPTIONAL,
      .inner = alloc::new(p.allocator,Node,inner)});
  }

  if(parser_match(p,LBRACKET))
  {
    Node inner = parse_expression(p).@or_else(;it) {
      return result::err(it.error);
    };
    parser_consume(p,RBRACKET,"expected '}'").@or_else(;it) {
      inner.free(p.allocator);
      return result::err(it.error);
    };
    return result::ok({.type = REPETITION,
      .inner = alloc::new(p.allocator,Node,inner)});
  }

  if(parser_match(p,LPAREN))
  {
    Node inner = parse_expression(p).@or_else(;it) {
      return result::err(it.error);
    };
    parser_consume(p,RPAREN,"expected ')'").@or_else(;it) {
      inner.free(p.allocator);
      return result::err(it.error);
    };
    return result::ok(inner);
  }

  if(parser_check(p, TERMINAL))
  {
    return result::ok({.type = TERMINAL,
      .terminal = parser_advance(p).lexeme.copy(p.allocator)});
  }

  if(parser_check(p,NON_TERMINAL))
  {
    return result::ok({.type = NON_TERMINAL,
      .non_terminal = parser_advance(p).lexeme.copy(p.allocator)});
  }

  return result::err((ParseError){
    .pos = parser_peek(p).pos, .msg = "Unexpected token"});
}

// Utils:
fn bool parser_match(Parser* p, TokenType type) @local
{
  if (parser_peek(p).type == type)
  {
    parser_advance(p);
    return true;
  }
  return false;
}

fn Token parser_peek(Parser* p) @local
{
  return p.scanner.tokens[p.i];
}

fn bool parser_is_at_end(Parser* p) @inline @local
{
  return parser_peek(p).type == EOF;
}

fn bool parser_check(Parser* p, TokenType type) @local
{
  if (parser_is_at_end(p)) return false;
  return parser_peek(p).type == type;
}

fn Token parser_advance(Parser* p) @inline @local
{
  return p.scanner.tokens[p.i++];
}

fn Result{Token, ParseError} parser_consume(Parser* p,
					    TokenType type,
					    String message) @local
{
  if (parser_check(p, type))
  {
    return result::ok(parser_advance(p));
  }
  else
  {
    return result::err{Token,ParseError}((ParseError) {
      .pos = parser_peek(p).pos,
      .msg = message });
  }
}

