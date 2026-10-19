# ebnf.c3l
[ISO-14977](http://www.iso.org/iso/en/CatalogueDetailPage.CatalogueDetail?CSNUMBER=26153) EBNF parser

# Usage

```c3
module testingebnf;

import std::io;
import std::os;
import ebnf;

fn int main(String[] args)
{
  if(args.len != 2)
  {
    io::eprintn("No filename provided!");
    os::exit(1);
  }

  String content = (String)file::load(mem,args[1])!!;
  defer mem::free(content);

  ebnf::Parser parser;
  parser.init(mem,args[1],content);
  defer parser.free();

  Ebnf ebnf = parser.parse().@or_else(;it) {
    ParseError err = it.error;
    io::eprintfn("%d:%d:%d: %s",
		 err.pos.row,err.pos.col,err.pos.offset,
		 err.msg);
    os::exit(1);
  };
  defer ebnf.free();
    
  io::printn(ebnf);

  return 0;
}
```

