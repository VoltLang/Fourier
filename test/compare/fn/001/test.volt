//T run:volta --no-backend -jo %t.json %S/test.volt
//T run:fourier -j %t.json %S/test.h
// Test aliased function pointer.
module test;

extern (C) fn takes_a_fn(arg: fn (i32) i32) void;
