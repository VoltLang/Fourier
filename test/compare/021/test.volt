//T retval:0
//T run:volta --no-backend -jo %t.json %S/test.volt
//T retval:1
//T run:fourier -j %t.json %S/test.h

struct S {
	x: string;
}
