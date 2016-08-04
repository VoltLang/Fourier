//T run:fourier -v %p/test.volt %p/test.h
//T compiles:yes
// Tests unions and floating point.
module test;

union S
{
	x: f32;
	y: f64;
}
