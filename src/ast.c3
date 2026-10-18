module ebnf;

import std::collections;
import std::io;
import std::core::mem::alloc;

enum NodeType
{
  TERMINAL,
  NON_TERMINAL,
  SEQUENCE,
  ALTERNATION,
  OPTIONAL,
  REPETITION,
}

struct Node(Printable)
{
  NodeType type;
  union
  {
    String terminal;
    String non_terminal;
    List{Node} children; // SEQUENCE,ALTERNATION
    Node* inner; // OPTIONAL,REPETITION
  }
}

fn Node Node.copy(&self, Allocator allocator)
{
  Node new_node;
  new_node.type = self.type;
  switch (self.type)
  {
    case TERMINAL:
      new_node.terminal = self.terminal.copy(allocator);
      break;
    case NON_TERMINAL:
      new_node.non_terminal = self.non_terminal.copy(allocator);
      break;
    case SEQUENCE:
    case ALTERNATION:
      new_node.children.init(allocator);
      foreach (child : self.children)
      {
	new_node.children.push(child.copy(allocator));
      }
      break;
    case OPTIONAL:
    case REPETITION:
      new_node.inner = alloc::malloc(allocator, Node::size);
      *new_node.inner = self.inner.copy(allocator);
      break;
  }
  return new_node;
}

fn void Node.free(&self, Allocator allocator)
{
  switch (self.type)
  {
    case TERMINAL:
      alloc::free(allocator, self.terminal);
      break;
    case NON_TERMINAL:
      alloc::free(allocator, self.non_terminal);
      break;
    case SEQUENCE:
    case ALTERNATION:
      foreach (&child : self.children) child.free(allocator);
      self.children.free();
      break;
    case OPTIONAL:
    case REPETITION:
      self.inner.free(allocator);
      alloc::free(allocator, self.inner);
      break;
  }
}

fn sz? Node.to_format(&self, Formatter* f) @dynamic
{
  sz len = f.printf("(Node){.type = %s, ", self.type)!;
  switch (self.type)
  {
    case TERMINAL:
      len += f.printf(".terminal = %s", self.terminal)!;
      break;
    case NON_TERMINAL:
      len += f.printf(".non_terminal = %s", self.non_terminal)!;
      break;
    case SEQUENCE:
    case ALTERNATION:
      len += self.children.to_format(f)!;
      break;
    case OPTIONAL:
    case REPETITION:
      len += self.inner.to_format(f)!;
      break;
  }
  return len;
}

struct Production(Printable)
{
  String lhs;
  Node rhs;
}

fn void Production.free(&self, Allocator allocator)
{
  alloc::free(allocator,self.lhs);
  self.rhs.free(allocator);
}

fn sz? Production.to_format(&self,Formatter* f) @dynamic
{
  sz len = f.printf("(Production){.lhs = %s, ", self.lhs)!;
  len += self.rhs.to_format(f)!;
  return len;
}

struct Ebnf(Printable)
{
  Allocator allocator;
  List{Production} productions;
}

fn void Ebnf.init(&self, Allocator allocator)
{
  self.allocator = allocator;
  self.productions.init(allocator);
}

fn void Ebnf.free(&self)
{
  foreach(&prod : self.productions)
  {
    prod.free(self.allocator);
  }
  self.productions.free();
}

fn sz? Ebnf.to_format(&self, Formatter* f) @dynamic
{
  sz len;
  foreach(&prod : self.productions) len += prod.to_format(f)!;
  return len;
}

