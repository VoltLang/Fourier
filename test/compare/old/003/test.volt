//T run:volta --no-backend -jo %t.json %S/test.volt
//T run:fourier -j %t.json %S/test.h
// Tests simple structs and integer types.
module test;

struct S
{
	a: i32;
	b: i16;
}
