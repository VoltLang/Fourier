//T run:volta --no-backend -jo %t.json %S/test.volt
//T run:fourier -j %t.json %S/test.h
// Test aliased function pointer.
module test;

alias func = fn (i32) i32;

extern (C) fn takes_a_fn(arg: func) void;
