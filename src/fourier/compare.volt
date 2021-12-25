// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/fourier/license.volt (BOOST ver. 1.0).
/*!
 * Compare Volt JSON output to a C header file.
 */
module fourier.compare;

import watt.conv : toStringz;
import watt.io;
import watt.path : temporaryFilename;
import watt.io.file : read ;
import watt.io.streams : OutputFileStream, InputFileStream;
import watt.process.spawn : spawnProcess;
import watt.text.format : format;
import core.c.stdio : unlink;

import lib.clang;  // Every clang_* function and CX* type.

import fourier.volt;
import fourier.util : getVoltString;
import fourier.walker;

/*!
 * List the important differences between a C header file, and the JSON output
 * of a Volt module (presumably binding the same file).
 *
 * Params:
 *   cPath: The filename of the C file to check.
 *   jsonPath: The filename of the JSON file to check.
 *
 * Returns: true if all tests passed.
 */
fn listDiscrepancies(cPath: string, jsonPath: string) bool
{
	jsonBases := loadJson(jsonPath);
	cContext := loadC(cPath);
	scope (exit) unloadC(cContext);

	cWalker := walk(cContext.tu, false, "");

	cNames := filterBases(cWalker.mod, filter.everything);
	jsonNames := filterBases(jsonBases, filter.everything);
	string indent = "";
	return nameComparison(cPath, cNames, jsonPath, jsonNames, indent);
}

fn ignoreName(name: string) bool
{
	version (OSX) {
		switch (name) {  // OS X specific ignores
		case "stdout":
		case "stderr":
		case "stdin": return true;
		default: break;
		}
	}
	switch (name) {
	case "va_list":
	case "size_t": return true;
	default: return name.length == 0 || name[0] == '_';
	}
}

// Compare two lists of bases, ensuring that all Named in cBases match and are in the same order.
fn strictNameComparison(cName: string, cBases: Base[], jName: string, jBases: Base[],
	indent: string) bool
{
	pass := true;
	foreach (i, cBase; cBases) {
		cNamed := cast(Named)cBase;
		if (cNamed is null) {
			continue;
		}
		if (i >= jBases.length) {
			writefln("%s'%s' from Volt doesn't define '%s'. [FAIL]", indent, jName, cNamed.name);
			pass = false;
			continue;
		}
		jNamed := cast(Named)jBases[i];
		if (jNamed is null || cNamed.name != jNamed.name) {
			writefln("%s'%s' in C has a named object '%s', whereas the Volt has named object '%s'. [FAIL]",
				indent, cName, cNamed.name, jNamed.name);
			pass = false;
			continue;
		}
		result := compare(cNamed, jNamed, indent);
		pass = result && pass;
	}
	return pass;
}

// Compare two lists of bases, ensuring that all Named in cBases match and are defined in jsonBases.
fn nameComparison(cName: string, cBases: Base[], jName: string, jsonBases: Base[],
	indent: string) bool
{
	cNames: Named[string];
	jsonNames: Named[string];

	foreach (cBase; cBases) {
		cNamed := cast(Named)cBase;
		if (cNamed is null) {
			continue;
		}
		cNames[cNamed.name] = cNamed;
	}

	foreach (jsonBase; jsonBases) {
		jsonNamed := cast(Named)jsonBase;
		if (jsonNamed is null) {
			continue;
		}
		jsonNames[jsonNamed.name] = jsonNamed;
	}

	bool pass = true;
	foreach (name, named; cNames) {
		if (ignoreName(name)) {
			continue;
		}
		jsonNamed := name in jsonNames;
		if (jsonNamed is null) {
			writefln("%s'%s' defines %s '%s' that is undefined by '%s'. [WARNING]",
				indent, cName, getStringFromKind(named.kind), name, jName);
			continue;
		}

		// If the C is an alias referring to a parent type (e.g. struct) that's anonymous, check that type instead.
		asAlias := cast(Alias)named;
		if (asAlias !is null) {
			referredType := asAlias.type in cNames;
			if (referredType !is null) {
				asParent := cast(Parent)*referredType;
				if (asParent !is null && asParent.isAnonymous) {
					named = asParent;
				}
			}
		}

		result := compare(named, *jsonNamed, indent);
		pass = pass && result;
	}
	return pass;
}

fn compare(cBase: Base, jBase: Base, indent: string) bool
{
	cFunc := cast(Function)cBase;
	jsonFunc := cast(Function)jBase;
	if (cFunc !is null && jsonFunc !is null) {
		return funcComparison(cFunc, jsonFunc, indent);
	}

	cParent := cast(Parent)cBase;
	jParent := cast(Parent)jBase;
	if (cParent !is null && jParent !is null) {
		return parentComparison(cParent, jParent, indent);
	}

	cVar := cast(Variable)cBase;
	jVar := cast(Variable)jBase;
	if (cVar !is null && jVar !is null) {
		return varComparison(cVar, jVar, indent);
	}

	cAlias := cast(Alias)cBase;
	jAlias := cast(Alias)jBase;
	if (cAlias !is null && jAlias !is null) {
		return aliasComparison(cAlias, jAlias, indent);
	}

	cEnumDecl := cast(EnumDecl)cBase;
	jEnumDecl := cast(EnumDecl)jBase;
	if (cEnumDecl !is null && jEnumDecl !is null) {
		if (cEnumDecl.value != jEnumDecl.value) {
			writefln("%sEnum %s values don't match C:%s Volt:%s [FAIL]",
				indent, cEnumDecl.name, cEnumDecl.value, jEnumDecl.value);
			return false;
		}
		return true;
	}

	if (cAlias !is null) {
		return true;
	}

	writefln("%sType mismatch C:%s Volt:%s [FAIL]", indent,
		getStringFromKind(cBase.kind), getStringFromKind(jBase.kind));
	return false;
}

/* By the time we get size_t from C via clang, it's been changed.
 * Nevertheless, the C standard says 'size_t', so check here.
 */
fn bothAreSizeT(c: string, j: string) bool
{
	if (j != "size_t") {
		return false;
	}
	version (X86_64) {
		return c == "c_ulong";
	} else {
		return c == "u32";
	}
}

fn typesEqual(c: string, j: string, indent: string) bool
{
	if (ignoreName(c)) {
		return true;
	}
	if (bothAreSizeT(c, j)) {
		return true;
	}
	return c == j;
}

fn aliasComparison(cAlias: Alias, jAlias: Alias, indent: string) bool
{
	assert(cAlias.name == jAlias.name);
	if (typesEqual(cAlias.type, jAlias.type, indent)) {
		return true;
	} else {
		writef("%sAlias '%s' type mismatch [FAIL]", indent, cAlias.name);
		writefln(" C:%s Volt:%s", cAlias.type, jAlias.type);
		return false;
	}
}

fn varComparison(cVar: Variable, jVar: Variable, indent: string) bool
{
	assert(cVar.name == jVar.name);
	if (typesEqual(cVar.type, jVar.type, indent)) {
		return true;
	} else {
		writefln("%s%s '%s' type mismatch C:%s Volt:%s [FAIL]", indent, indent == "" ? "variable" : "field",
			cVar.name, cVar.type, jVar.type);
		return false;
	}
}

fn indentString(named: Named) string
{
	return format("(%s %s) ", getStringFromKind(named.kind), named.name);
}

fn parentComparison(cParent: Parent, jParent: Parent, indent: string) bool
{
	c := filterBases(cParent.children, filter.everything);
	j := filterBases(jParent.children, filter.everything);
	result := strictNameComparison(cParent.name, c, jParent.name, j, indentString(cParent));
	return result;
}

fn funcComparison(cFunction: Function, jsonFunction: Function, indent: string) bool
{
	fn warn(reason: string)
	{
		writefln("%sFunction '%s' match failure. (%s) [WARNING]", indent, cFunction.name, reason);
	}

	fn fail(reason: string) bool
	{
		writefln("%sFunction '%s' match failure. (%s) [FAIL]", indent, cFunction.name, reason);
		return false;
	}

	if (jsonFunction.hasBody) {
		// This is probably a wrapper function, assume they've got it right.
		return true;
	}
	if (cFunction.args.length != jsonFunction.args.length ||
	    cFunction.rets.length != jsonFunction.rets.length) {
		return fail("number of args or return types don't match");
	}
	if (jsonFunction.linkage != Linkage.C) {
		return fail("non C linkage");
	}
	foreach (i; 0 .. cFunction.args.length) {
		cArg := cast(Arg)cFunction.args[i];
		jArg := cast(Arg)jsonFunction.args[i];
		if (cArg is null || jArg is null) {
			return fail("not a valid argument");
		}
		if (typedEqual(cArg, jArg, indent)) {
			continue;
		}

		cStr := formatTyped(cArg);
		jStr := formatTyped(jArg);

		if (typedFullEquals(cArg, jArg, indent)) {
			warn(format("argument '%s' mismatch C:%s Volt:%s", cArg.name, cStr, jStr));
			continue;
		}

		return fail(format("argument '%s' mismatch C:%s Volt:%s", cArg.name, cStr, jStr));
	}

	foreach (i; 0 .. cFunction.rets.length) {
		cRet := cast(Return)cFunction.rets[i];
		jRet := cast(Return)jsonFunction.rets[i];
		if (cRet is null || jRet is null) {
			return fail("not a valid return");
		}

		if (typedEqual(cRet, jRet, indent)) {
			continue;
		}

		cStr := formatTyped(cRet);
		jStr := formatTyped(jRet);

		if (typedFullEquals(cRet, jRet, indent)) {
			warn(format("return mismatch C:%s Volt:%s", cStr, jStr));
			continue;
		}

		return fail(format("return mismatch C:%s Volt:%s", cStr, jStr));
	}

	return true;
}

/*!
 * Returns a Named from bases that has the name name, or null.
 */
fn getName(bases: Base[], name: string) Named
{
	foreach (base; bases) {
		named := cast(Named)base;
		if (named is null) {
			continue;
		}
		if (named.name == name) {
			return named;
		}
	}
	return null;
}

/*!
 * Temporary: List the structs names.
 */
fn listStructs(filename: string, structs: Base[])
{
	writefln("'%s' defines %s structs:", filename, structs.length);
	foreach (_struct; structs) {
		named := cast(Named)_struct;
		assert(named !is null);
		writefln("struct %s", named.name);
	}
}

/*!
 * Load and parse a JSON file.
 *
 * Params:
 *   jsonPath: The path to the JSON file to parse.
 * Returns: An array of Base objects, generated by fourier.volt.parse.
 */
fn loadJson(jsonPath: string) Base[]
{
	str := cast(string)read(jsonPath);
	return parse(str);
}

/*!
 * Holds pieces of information together, for libclang.
 */
struct ClangContext
{
	index: CXIndex;
	tu: CXTranslationUnit;
}

/*!
 * libclang doesn't know anything about the default search paths.
 * Ask clang about them, and append them to args.
 */
fn addDefaultPaths(ref args: const(char)*[])
{
	fname := temporaryFilename("fourierclangoutput", "fourier");
	ofs := new OutputFileStream(fname);
	scope (exit) unlink(toStringz(fname));
	pid := spawnProcess("/bin/sh", ["-c", "echo | clang -v -S -x c - -o -"],
		null, ofs, ofs, null);
	pid.wait();
	ofs.close();
	ifs := new InputFileStream(fname);
	searching := false;
	while (!ifs.eof()) {
		line := ifs.readln();
		if (!searching && line == "#include <...> search starts here:") {
			searching = true;
			continue;
		}
		if (!searching) {
			continue;
		}
		if (line == "End of search list.") {
			break;
		}
		assert(line.length > 1);
		args ~= toStringz(format("-I%s", line[1 .. $]));  // 1 == leading space
	}
	ifs.close();
}

/*!
 * Initialise libclang, and parse a C file.
 *
 * Params:
 *   cPath: The path to the C file to parse.
 * Returns: A ClangContext.
 */
fn loadC(cPath: string) ClangContext
{
	context: ClangContext;
	context.index = clang_createIndex(0, 0);
	args := ["-I.".ptr, "-o".ptr, "-".ptr];
	version (!MSVC) {
		addDefaultPaths(ref args);
	}
	context.tu = clang_parseTranslationUnit(context.index, cPath.ptr, args.ptr,
		cast(i32)args.length, null, 0, CXTranslationUnit_None);
	context.tu.printDiag(cPath);
	return context;
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

/*!
 * Clean up a ClangContext from loadC.
 */
fn unloadC(context: ClangContext)
{
	clang_disposeTranslationUnit(context.tu);
	clang_disposeIndex(context.index);
}

/*!
 * Return the Bases that match a given filter.
 *
 * Params:
 *   bases: The array of Bases to filter.
 *   dg: The filter to apply. This will be run on each member of
 *       bases, and only those which of which it returns true will
 *       be returned.
 * Returns: An array of Bases that the dg applies to, or an empty list.
 */
fn filterBases(bases: Base[], dgt: filterdg) Base[]
{
	ret: Base[];
	foreach (base; bases) {
		if (dgt(base)) {
			ret ~= base;
		}
		parent := cast(Parent)base;
		if (parent !is null && parent.kind == Kind.Module) {
			ret ~= filterBases(parent.children, dgt);
		}
	}
	return ret;
}

alias filterdg = bool delegate(Base);
private struct Filter
{
	fn everything(base: Base) bool
	{
		return true;
	}
}
private global Filter filter;


/*!
 * Tests two typed for equality.
 */
private fn typedEqual(a: Typed, b: Typed, indent: string) bool
{
	// Simple check.
	return typesEqual(a.type, b.type, indent);
}

/*!
 * Tests two typed for equality, also taking in account full.
 */
private fn typedFullEquals(a: Typed, b: Typed, indent: string) bool
{
	if (a.typeFull is null && b.typeFull is null) {
		return false;
	}

	aStr := a.typeFull !is null ? a.typeFull : a.type;
	bStr := b.typeFull !is null ? b.typeFull : b.type;

	return typesEqual(aStr, bStr, indent);
}

/*!
 * Format two typed taking into account typeFull.
 */
private fn formatTyped(t: Typed) string
{
	if (t.typeFull is null ||
	    t.type == t.typeFull) {
		return new "'${t.type}'";
	}

	return new "'${t.type} (aka '${t.typeFull}')";
}
