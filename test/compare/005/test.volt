//T retval:0
//T run:volta -c -jo %t.json %S/test.volt
//T retval:1
//T run:fourier -j %t.json %S/test.h
// Tests simple function failure.
module test;

fn add(i32, i32) i32;
