module ebnf;

import std::collections;
import std::io;

struct Ebnf
{
	// TODO: make this hashset to avoid duplicate productions.
	List{Production} productions;
}

fn void Ebnf.init(&self, Allocator allocator)
{
	self.productions.init(allocator);
}

fn void Ebnf.free(&self)
{
	foreach (&p : self.productions) p.free();
	self.productions.free();
}

fn sz? Ebnf.to_format(&self, Formatter* f) @dynamic
{
	sz len = f.printf("(Ebnf){.productions = ")!;
	len += self.productions.to_format(f)!;
	len += f.print("}")!;
	return len;
}

struct Production
{
	String lhs;
	Expression rhs;
}

fn void Production.free(&self)
{
	self.rhs.free();
}

fn sz? Production.to_format(&self, Formatter* f) @dynamic
{
	sz len = f.printf("(Production){.lhs = %s, .rhs = ", self.lhs)!;
	len += self.rhs.to_format(f)!;
	len += f.print("}")!;
	return len;
}

struct Expression
{
	List{Term} terms;
}

fn void Expression.free(&self)
{
	foreach (&term : self.terms) term.free();
	self.terms.free();
}

fn sz? Expression.to_format(&self, Formatter* f) @dynamic
{
	sz len = f.print("(Expression){.terms = ")!;
	len += self.terms.to_format(f)!;
	len += f.print("}")!;
	return len;
}

struct Term
{
	List{Factor} factors;
}

fn void Term.free(&self)
{
	foreach (&factor : self.factors) factor.free();
	self.factors.free();
}

fn sz? Term.to_format(&self, Formatter* f) @dynamic
{
	sz len = f.print("(Term){.factors = ")!;
	len += self.factors.to_format(f)!;
	len += f.print("}")!;
	return len;
}

enum FactorType
{
	TERMINAL,
	NON_TERMINAL,
	OPTIONAL,
	GROUPING,
	REPETITION
}

struct Factor
{
	FactorType type;
	union
	{
		String terminal;
		String non_terminal;
		Expression optionals;
		Expression groupings;
		Expression repetitions;
	}
}

fn void Factor.free(&self)
{
	switch (self.type)
	{
		case OPTIONAL:
			self.optionals.free();
			break;
		case GROUPING:
			self.groupings.free();
			break;
		case REPETITION:
			self.repetitions.free();
			break;
		default:
			break;
	}
}

fn sz? Factor.to_format(&self, Formatter* f) @dynamic
{
	sz len = f.printf("(Factor){.type = %s, ", self.type)!;
	switch (self.type)
	{
		case TERMINAL:
			len += f.printf("TERMINAL(%s)", self.terminal)!;
			break;
		case NON_TERMINAL:
			len += f.printf("NON_TERMINAL(%s)", self.non_terminal)!;
			break;
		case OPTIONAL:
			len += self.optionals.to_format(f)!;
			break;
		case GROUPING:
			len += self.groupings.to_format(f)!;
			break;
		case REPETITION:
			len += self.repetitions.to_format(f)!;
			break;
	}
	len += f.print("}")!;
	return len;
}
