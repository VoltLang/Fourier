//T run:volta --no-backend -jo %t.json %S/test.volt
//T run:fourier -j %t.json %S/test.h
// Test aliased function pointer.
module test;

alias wchar_t = i32;

extern(C) fn func(arg: wchar_t*);
