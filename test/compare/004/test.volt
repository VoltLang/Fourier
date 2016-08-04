//T run:fourier -v %p/test.volt %p/test.h
//T compiles:yes
// Tests simple functions.
module test;

extern (C) fn add(i32, i32) i32;
