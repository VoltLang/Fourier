//T retval:0
//T run:volta -c -jo %t.json %S/test.volt
//T retval:1
//T run:fourier -j %t.json %S/test.h
// Tests that const checking affects passing.
module test;

extern (C) fn foo(void*, char*) void;
