//T run:volta -c -jo %t.json %S/test.volt
//T run:fourier -j %t.json %S/test.h
// Tests aliases.
module test;

alias newImprovedInt = i32;
