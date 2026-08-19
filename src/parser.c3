module ebnf;

import std::collections;
import std::io;
import std::os;
import std::core::mem::alloc;

struct ParserError
{
	Position pos;
	String msg;
}

fn sz? ParserError.to_format(&self, Formatter* f) @dynamic
{
	sz len = f.print("(ParserError){.pos = ")!;
	len += self.pos.to_format(f)!;
	len += f.printf(", .msg = %s}", self.msg)!;
	return len;
}

struct Parser
{
	Allocator allocator;
	Position pos;
	sz i;
	List{Token}* tokens;
}

fn void Parser.init(&self, Allocator allocator, List{Token}* tokens)
{
	self.allocator = allocator;
	self.tokens = tokens;
}

fn Result{Ebnf, ParserError} parse(Parser* p)
{
	Ebnf ebnf;
	ebnf.init(p.allocator);
	while (peek(p).type != EOF)
	{
		Production prod = parse_production(p).@or_else(; it)
		{
			return result::err(it.error);
		};
		ebnf.productions.push(prod);
	}
	return result::ok(ebnf);
}

// Private:
fn Result{Production, ParserError} parse_production(Parser* p) @local
{
	Production prod;
	Token tok = consume(p, NON_TERMINAL, "Expected nonterminal").@or_else(; it)
	{
		return result::err(it.error);
	};

	prod.lhs = tok.lexeme;

	consume(p, EQUAL, "Expected equal sign").@or_else(; it)
	{
		return result::err(it.error);
	};

	prod.rhs = parse_expression(p).@or_else(; it)
	{
		return result::err(it.error);
	};

	consume(p, DOT, "Expected '.' after production's rhs").@or_else(; it)
	{
		return result::err(it.error);
	};

	return result::ok(prod);
}

fn Result{Node, ParserError} parse_expression(Parser* p) @local
{
	List{Node} alternatives;
	alternatives.init(p.allocator);
	alternatives.push(parse_term(p).@or_else(; it)
	{
		return result::err(it.error);
	});

	while (peek(p).type == TokenType.BAR)
	{
		alternatives.push(parse_term(p).@or_else(; it)
		{
			return result::err(it.error);
		});
	}

	if (alternatives.len() == 1)
	{
		Node one = alternatives[0].copy(p.allocator);
		alternatives.free();
		return result::ok(one);
	}

	return result::ok({ .type = ALTERNATION, .children = alternatives });
}

fn Result{Node, ParserError} parse_term(Parser* p) @local
{
	List{Node} sequence;
	sequence.init(p.allocator);
	sequence.push(parse_factor(p).@or_else(; it)
	{
		return result::err(it.error);
	});

	while (true)
	{
		if (check(p, BAR) || check(p, DOT) || check(p, RPAREN) || check(p, RSBRACKET) || check(p, RBRACKET))
		{
			break;
		}

		sequence.push(parse_factor(p).@or_else(; it)
		{
			return result::err(it.error);
		});
	}

	if (sequence.len() == 1)
	{
		Node one = sequence[0].copy(p.allocator);
		sequence.free();
		return result::ok(one);
	}

	return result::ok({ .type = SEQUENCE, .children = sequence });
}

fn Result{Node, ParserError} parse_factor(Parser* p) @local
{
	if (match(p, LSBRACKET))
	{
		Node inner = parse_expression(p).@or_else(; it)
		{
			return result::err(it.error);
		};
		consume(p, RSBRACKET, "expected ']'");
		return result::ok({ .type = OPTIONAL, .inner = alloc::new(p.allocator, Node, inner), });
	}

	if (match(p, LBRACKET))
	{
		Node inner = parse_expression(p).@or_else(; it)
		{
			return result::err(it.error);
		};
		consume(p, RBRACKET, "expected '}'");
		return result::ok({ .type = REPETITION, .inner = alloc::new(p.allocator, Node, inner), });
	}

	if (match(p, LPAREN))
	{
		Node inner = parse_expression(p).@or_else(; it)
		{
			return result::err(it.error);
		};
		consume(p, RPAREN, "expected ')'");
		return result::ok(inner);
	}

	if (check(p, TERMINAL)) return result::ok({ .type = TERMINAL, .terminal = advance(p).lexeme });

	return result::ok({ .type = NON_TERMINAL, .non_terminal = advance(p).lexeme });
}

// Utils:
fn bool match(Parser* p, TokenType type) @local
{
	if (peek(p).type == type)
	{
		advance(p);
		return true;
	}
	return false;
}

fn Token peek(Parser* p) @local
{
	return (*p.tokens)[p.i];
}

fn bool isAtEnd(Parser* p) @inline @local
{
	return peek(p).type == EOF;
}

fn bool check(Parser* p, TokenType type) @local
{
	if (isAtEnd(p)) return false;
	return peek(p).type == type;
}

fn Token advance(Parser* p) @inline @local
{
	return (*p.tokens)[p.i++];
}

fn Result{Token, ParserError} consume(Parser* p, TokenType type, String message) @local
{
	if (check(p, type))
	{
		return result::ok(advance(p));
	}
	else
	{
		return result::err{Token, ParserError}((ParserError) { .pos = peek(p).pos, .msg = message });
	}
}
