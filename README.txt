From https://www.cis.upenn.edu/~plclub/popl08-tutorial/code/index.html

- The primary source of documentation for everything here is contained in
  the doc/ directory.  Start with doc/index.html.

- In order to work through the tutorial, you will need to compile our
  library for programming language metatheory.  Run

      make Metatheory.vo

  to compile the library.

  If you do not have make, run the following commands instead.

      coqc AdditionalTactics.v
      coqc ListFacts.v
      coqc FiniteSets.v
      coqc Negation.v
      coqc FSetDecide.v
      coqc FSetNotin.v
      coqc Atom.v
      coqc Environment.v
      coqc Metatheory.v

- If you would like to compile all the Coq files here---for example, in
  order to step through the Fsub solutions---run 'make -k'.  You need to
  pass the '-k' option to 'make' since one file, STLC_Tutorial.v, does not
  compile as given.  This is intentional.  The tutorial will guide you
  through updating the file so that it does compile.
