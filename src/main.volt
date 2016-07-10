// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/fourier/license.volt (BOOST ver. 1.0).
module main;

import lib.clang;

import watt.conv;
import watt.io;


fn main(args: string[]) i32
{
	test();
	return 0;
}

fn test() void
{
	index := clang_createIndex(0, 0);
	args := ["-I.".ptr];
	file := "test/test.c";
	tu := clang_parseTranslationUnit(index,
		file.ptr, args.ptr, cast(int)args.length,
		null, 0, CXTranslationUnit_None);

	tu.printDiag(file);
	tu.walk();

	clang_disposeTranslationUnit(tu);
	clang_disposeIndex(index);
}

fn printDiag(tu: CXTranslationUnit, file: string) void
{
	count := clang_getNumDiagnostics(tu);

	foreach (i; 0 .. count) {
		loc: CXSourceLocation;
		diag: CXDiagnostic;
		text: CXString;
		info: string;
		line, column: u32;

		diag = clang_getDiagnostic(tu, i);
		clang_getDiagnosticLocation(out loc, diag);
		text = clang_getDiagnosticSpelling(diag);

		clang_getSpellingLocation(loc, null, &line, &column, null);
		info = toString(clang_getCString(text));
		clang_disposeString(text);

		output.writefln("%s:%s:%s info %s", file, line, column, info);
	}
}

class Walker
{
	int ident;
}

fn walk(tu: CXTranslationUnit) void
{
	w := new Walker();
	ptr := cast(void*)w;

	coursor := clang_getTranslationUnitCursor(tu);
	clang_visitChildren(coursor, visit, ptr);
}

fn visit(cursor: CXCursor, p: CXCursor, ptr: void*) CXChildVisitResult
{
	w := cast(Walker)ptr;

	foreach (0 .. w.ident) {
		writef("  ");
	}
	writefln("+- %s", cursor.kind);
	w.ident++;
	clang_visitChildren(cursor, visit, ptr);
	w.ident--;
	return CXChildVisit_Continue;
}
