// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/fourier/license.volt (BOOST ver. 1.0).
module main;

import watt.io;
import watt.text.getopt;

import lib.clang;

import fourier.walker;
import fourier.util;

fn main(args: string[]) i32
{
	bool printDebug, printUsage;
	getopt(ref args, "debug|d", ref printDebug);
	getopt(ref args, "help|h", ref printUsage);
	if (printUsage) {
		usage();
		return 0;
	}

	test(args.length > 1 ? args[1] : "test/test.c", printDebug);
	return 0;
}

fn usage()
{
	writeln("fourier [flags] <C source file>");
	writeln("\t--debug|-d  print additional information about the source file.");
	writeln("\t--help|-h   print this message and exit.");
}

fn test(file: string, printDebug: bool)
{
	index := clang_createIndex(0, 0);
	args := ["-I.".ptr];
	tu := clang_parseTranslationUnit(index,
		file.ptr, args.ptr, cast(int)args.length,
		null, 0, CXTranslationUnit_None);

	tu.printDiag(file);
	tu.walk(printDebug, getModuleName(file));

	clang_disposeTranslationUnit(tu);
	clang_disposeIndex(index);
}

fn printDiag(tu: CXTranslationUnit, file: string)
{
	count := clang_getNumDiagnostics(tu);

	foreach (i; 0 .. count) {
		loc: CXSourceLocation;
		diag: CXDiagnostic;
		text: CXString;
		info: string;
		line, column: u32;

		diag = clang_getDiagnostic(tu, i);
		loc = clang_getDiagnosticLocation(diag);
		text = clang_getDiagnosticSpelling(diag);

		clang_getSpellingLocation(loc, null, &line, &column, null);
		info = getVoltString(text);

		output.writefln("%s:%s:%s info %s", file, line, column, info);
	}
}