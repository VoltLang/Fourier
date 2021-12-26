//T run:volta --no-backend -jo %t.json %S/test.volt
//T run:fourier -j %t.json %S/test.h
// Test aliased function pointer.
module test;

alias the_i32 = i32;

extern(C) fn func(arg: the_i32*);
