//T run:fourier -v %p/test.volt %p/test.h
//T compiles:yes
// Tests simple structs and integer types.
module test;

struct S
{
	a: i32;
	b: i16;
}
