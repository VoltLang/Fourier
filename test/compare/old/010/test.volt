//T run:volta --no-backend -jo %t.json %S/test.volt
//T run:fourier -j %t.json %S/test.h
// Tests unions and floating point.
module test;

union S
{
	x: f32;
	y: f64;
}
