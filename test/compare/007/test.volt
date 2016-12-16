//T retval:0
//T run:volta --no-backend -jo %t.json %S/test.volt
//T retval:1
//T run:fourier -j %t.json %S/test.h
// Tests simple function return failure.
module test;

fn add(i32, i32) void;
