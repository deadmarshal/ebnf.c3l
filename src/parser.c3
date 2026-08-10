module ebnf;

import std::collections;
import std::io;
import std::os;

struct ParserError
{
	Position pos;
	String msg;
}

struct Parser
{
	Allocator allocator;
	sz i;
	List{Token}* tokens;
	Ebnf ebnf;
}

fn void Parser.init(&self, Allocator allocator, List{Token}* tokens)
{
	self.allocator = allocator;
	self.tokens = tokens;
}

fn Result{Ebnf, ParserError} Parser.parse(&self)
{
	Ebnf ebnf;
	ebnf.init(self.allocator);

	while (self.peek().type != EOF)
	{
		ebnf.productions.push(self.parse_production().@or_else(; it)
		{
			return result::err(it.error);
		});
	}

	return result::ok(ebnf);
}

// Private:
fn Result{Production, ParserError} Parser.parse_production(&self)
{
	Production prod;
	Token tok = self.consume(NON_TERMINAL, "Expected nonterminal").@or_else(; it)
	{
		return result::err(it.error);
	};
	prod.lhs = tok.lexeme;

	self.consume(EQUAL, "Expected equal sign").@or_else(; it)
	{
		return result::err(it.error);
	};
	prod.rhs = self.parse_expression().@or_else(; it)
	{
		return result::err(it.error);
	};
	self.consume(DOT, "Expected '.' after production's rhs").@or_else(; it)
	{
		return result::err(it.error);
	};
	return result::ok(prod);
}

fn Result{Expression, ParserError} Parser.parse_expression(&self)
{
	Expression expr;
	expr.terms.init(self.allocator);
	expr.terms.push(self.parse_term().@or_else(; it)
	{
		return result::err(it.error);
	});
	while (true)
	{
		if (self.peek().type == BAR)
		{
			self.advance();
			expr.terms.push(self.parse_term().@or_else(; it)
			{
				return result::err(it.error);
			});
		}
		else
		{
			break;
		}
	}
	return result::ok(expr);
}

fn Result{Term, ParserError} Parser.parse_term(&self)
{
	Term term;
	term.factors.init(self.allocator);

	while (true)
	{
		if (self.check(BAR) || self.check(DOT) || self.check(RPAREN) || self.check(RSBRACKET) || self.check(RBRACKET))
		{
			break;
		}
		term.factors.push(self.parse_factor().@or_else(; it)
		{
			return result::err(it.error);
		});
	}
	return result::ok(term);
}

fn Result{Factor, ParserError} Parser.parse_factor(&self)
{
	Factor factor;
	switch (self.peek().type)
	{
		case TokenType.NON_TERMINAL:
			factor.type = NON_TERMINAL;
			factor.non_terminal = self.advance().lexeme.copy(tmem);
			return result::ok(factor);
		case TokenType.TERMINAL:
			factor.type = TERMINAL;
			factor.terminal = self.advance().lexeme.copy(tmem);
			return result::ok(factor);
		case LSBRACKET:
			self.advance();
			factor.type = OPTIONAL;
			factor.optionals = self.parse_expression().@or_else(; it)
			{
				return result::err(it.error);
			};
			self.consume(RSBRACKET, "expected ']'").@or_else(; it)
			{
				return result::err(it.error);
			};
			return result::ok(factor);
		case LPAREN:
			self.advance();
			factor.type = GROUPING;
			factor.groupings = self.parse_expression().@or_else(; it)
			{
				return result::err(it.error);
			};
			self.consume(RPAREN, "Expected ')'").@or_else(; it)
			{
				return result::err(it.error);
			};
			return result::ok(factor);
		case LBRACKET:
			self.advance();
			factor.type = REPETITION;
			factor.repetitions = self.parse_expression().@or_else(; it)
			{
				return result::err(it.error);
			};
			self.consume(RBRACKET, "Expected '}'").@or_else(; it)
			{
				return result::err(it.error);
			};
			return result::ok(factor);
		default:
			return result::err((ParserError) { .pos = self.peek()
				.pos, .msg = "Expected '[' or '(' or '{' or identifier or non_terminal in factor", });
	}
}

// Private:
fn bool Parser.isAtEnd(&self) @inline
{
	return self.peek().type == EOF;
}

fn bool Parser.check(&self, TokenType type)
{
	if (self.isAtEnd()) return false;
	return self.peek().type == type;
}

fn Token Parser.advance(&self)
{
	while (!self.isAtEnd() && (*self.tokens)[self.i].type == COMMENT)
	{
		self.i++;
	}

	return (*self.tokens)[self.i++];
}

fn Token Parser.peek(&self) @inline
{
	while((*self.tokens)[self.i].type == COMMENT)
	{
		// skip comments.
		self.i++;
	}
	return (*self.tokens)[self.i];
}

fn Result{Token, ParserError} Parser.consume(&self, TokenType type, String message)
{
	if (self.check(type))
	{
		return result::ok(self.advance());
	}
	else
	{
		return result::err{Token, ParserError}((ParserError) { .pos = self.peek().pos, .msg = message });
	}
}
