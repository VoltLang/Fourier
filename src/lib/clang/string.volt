// Copyright 2016, Jakob Bornecrantz.
// See copyright notice in src/fourier/license.volt (BOOST ver. 1.0).
module lib.clang.string;

private import watt.conv;
public import lib.clang.c.CXString;


string clang_getVoltString(CXString text)
{
	str := lib.clang.c.CXString.clang_getCString(text);
	return toString(str);
}
