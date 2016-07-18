// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/fourier/license.volt (BOOST ver. 1.0).
module fourier.walker;

import watt.io;
import watt.text.format : format;
import watt.math.random : RandomGenerator;

import lib.clang;

import fourier.visit;

class Walker
{
	indent: i32;
	tu: CXTranslationUnit;
	random: RandomGenerator;
	names: string[string];

	this(tu: CXTranslationUnit)
	{
		this.tu = tu;
		this.names["hi"] = "hello";
	}

	fn writeIndent()
	{
		foreach (0 .. indent) {
			writef("  ");
		}
	}

	fn getAnonymousName(id : string) string
	{
		if (p := id in names) {
			return *p;
		}
		names[id] = format("__%sAnon%s", id, random.randomString(6));
		return names[id];
	}
}

fn walk(tu: CXTranslationUnit)
{
	w := new Walker(tu);
	ptr := cast(void*)w;
	cursor := clang_getTranslationUnitCursor(tu);

	visit(cursor, CXCursor.init, ptr);

	writefln("");
	writefln("import core.stdc.config;\n");

	// Print all top level function decls.
	clang_visitChildren(cursor, visitAndPrint, ptr);
}