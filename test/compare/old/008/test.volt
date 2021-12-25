//T run:volta --no-backend -jo %t.json %S/test.volt
//T run:fourier -j %t.json %S/test.h
// Tests some pointers.
module test;

extern (C) fn foo(void*, const(char)*) void;
