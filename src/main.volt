// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/fourier/license.volt (BOOST ver. 1.0).
module main;

import watt.conv : toStringz;
import watt.io;
import watt.io.file : read;
import watt.text.getopt;
import watt.process;
import watt.path : temporaryFilename;
import core.stdc.stdio : unlink;

import lib.clang;

import fourier.walker;
import fourier.util;
import fourier.volt;
import fourier.compare;

fn main(args: string[]) i32
{
	printDebug, printUsage : bool;
	moduleName, jsonName, voltSource : string;
	getopt(ref args, "debug|d", ref printDebug);
	getopt(ref args, "help|h", ref printUsage);
	getopt(ref args, "module|m", ref moduleName);
	getopt(ref args, "json|j", ref jsonName);
	getopt(ref args, "volt|v", ref voltSource);
	if (printUsage) {
		usage();
		return 0;
	}
	arg := args.length > 1 ? args[1] : "test/test.c";
	if (jsonName != "") {
		return listDiscrepancies(arg, jsonName) ? 0 : 1;
	} else if (voltSource != "") {
		return testVoltGenerationAgainstCFile(arg, voltSource) ? 0 : 1;
	} else {
		test(arg, printDebug, moduleName);
	}
	return 0;
}

fn usage()
{
	writeln("fourier [flags] <C source file>");
	writeln("\t--debug|-d   print additional information about the source file.");
	writeln("\t--help|-h    print this message and exit.");
	writeln("\t--module|-m  override the default module name for the created module.");
	writeln("\t--json|-j    supply a JSON file to compare the header file against.");
	writeln("\t--volt|-v    invoke $VOLT to create a json file from, and compare against the header file.");
}

fn testVoltGenerationAgainstCFile(cSource: string, voltSource: string) bool
{
	jsonFile := temporaryFilename(".json");
	pid := spawnProcess(getEnv("VOLT"), ["-c", "-jo", jsonFile, voltSource]);
	pid.wait();
	ret := listDiscrepancies(cSource, jsonFile);
	unlink(toStringz(jsonFile));
	return ret;
}

fn test(file: string, printDebug: bool, moduleName: string)
{
	index := clang_createIndex(0, 0);
	args := ["-I.".ptr];
	tu := clang_parseTranslationUnit(index,
		file.ptr, args.ptr, cast(int)args.length,
		null, 0, CXTranslationUnit_None);

	tu.printDiag(file);
	tu.walkAndPrint(printDebug, moduleName != "" ? moduleName : getModuleName(file));

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

		error.writefln("%s:%s:%s info %s", file, line, column, info);
	}
}
