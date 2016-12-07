//T run:volta -c -jo %t.json %S/test.volt
//T run:fourier -j %t.json %S/test.h
// Tests simple functions.
module test;

extern (C) fn add(i32, i32) i32;
