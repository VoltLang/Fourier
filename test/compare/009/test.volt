//T run:fourier -v %p/test.volt %p/test.h
//T compiles:no
// Tests that const checking affects passing.
module test;

extern (C) fn foo(void*, char*) void;
