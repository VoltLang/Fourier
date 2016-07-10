// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/fourier/license.volt (BOOST ver. 1.0).
module main;

import lib.clang;
import watt.io;


fn main(args : string[]) i32
{
	test();
	return 0;
}

fn test() void
{
	index := clang_createIndex(0, 0);
	args := ["-I.".ptr];
	tu := clang_parseTranslationUnit(index,
		"test/test.c", args.ptr, cast(int)args.length,
		null, 0, CXTranslationUnit_None);

	tu.walk();
}

fn printDiag(tu : CXTranslationUnit) void
{
	diagnosticCount := clang_getNumDiagnostics(tu);

	foreach (i; 0 .. diagnosticCount) {
		diagnostic : CXDiagnostic = clang_getDiagnostic(tu, i);
		location : CXSourceLocation = clang_getDiagnosticLocation(diagnostic);
		text : CXString = clang_getDiagnosticSpelling(diagnostic);
		line, column : u32;
		clang_getSpellingLocation(location, null, &line, &column, null);
	}
}

fn walk(tu : CXTranslationUnit) void
{
	coursor := clang_getTranslationUnitCursor(tu);
	clang_visitChildren(coursor, visit, null);
}

fn visit(cursor : CXCursor, p : CXCursor, void*) CXChildVisitResult
{
	writefln("visit: %s", cursor.kind);
	return CXChildVisit_Continue;
}
