// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/fourier/license.volt (BOOST ver. 1.0).
module lib.clang.string;

private import watt.conv;
public import lib.clang.c.CXString;


string clang_getVoltString(CXString text)
{
	str := lib.clang.c.CXString.clang_getCString(text.data, text.private_flags);
	return toString(str);
}

const(char)* clang_getCString(CXString text)
{
	return lib.clang.c.CXString.clang_getCString(text.data, text.private_flags);
}

void clang_disposeString(CXString text)
{
	lib.clang.c.CXString.clang_disposeString(text.data, text.private_flags);
}
