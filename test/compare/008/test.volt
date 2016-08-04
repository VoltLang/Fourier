//T run:fourier -v %p/test.volt %p/test.h
//T compiles:yes
// Tests some pointers.
module test;

extern (C) fn foo(void*, const(char)*) void;
