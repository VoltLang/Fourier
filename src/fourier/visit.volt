// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/fourier/license.volt (BOOST ver. 1.0).
module fourier.visit;

import watt.io;

import lib.clang;

import fourier.walker;
import fourier.util;

fn visit(cursor: CXCursor, p: CXCursor, ptr: void*) CXChildVisitResult
{
	w := cast(Walker)ptr;
	assert(w !is null);

	w.writeIndent();
	foo: i32;

	// Print the kind of node we are standing on.
	writef("+- %s ", cursor.kind.toString());

	// Print the type of this node.
	type := clang_getCursorType(cursor);
	if (type.kind != CXType_Invalid) {
		writef("   \"");
		type.printType();
		writefln("\"");
	} else {
		writefln("");
	}

	// Visit children.
	w.indent++;
	clang_visitChildren(cursor, visit, ptr);
	w.indent--;

	// Done here.
	return CXChildVisit_Continue;
}

fn visitAndPrint(cursor: CXCursor, p: CXCursor, ptr: void*) CXChildVisitResult
{
	w := cast(Walker)ptr;
	assert(w !is null);

	switch (cursor.kind) {
	case CXCursor_TypedefDecl: doTypedefDecl(ref cursor, w); break;
	case CXCursor_FunctionDecl: doFunctionDecl(ref cursor, w); break;
	case CXCursor_StructDecl: doStructDecl(ref cursor, w); break;
	case CXCursor_UnionDecl: doUnionDecl(ref cursor, w); break;
	case CXCursor_VarDecl: doVarDecl(ref cursor, w); break;
	case CXCursor_IntegerLiteral: doIntLiteral(ref cursor, w); break;
	default:
	}

	return CXChildVisit_Continue;
}

fn assignVisitAndPrint(cursor: CXCursor, p: CXCursor, ptr: void*) CXChildVisitResult
{
	write(" = ");
	visitAndPrint(cursor, p, ptr);
	return CXChildVisit_Continue;
}

fn visitFieldAndPrint(cursor: CXCursor, ptr: void*) CXVisitorResult
{
	w := cast(Walker)ptr;
	assert(w !is null);

	switch (cursor.kind) {
	case CXCursor_FieldDecl:
		doVarDecl(ref cursor, w);
		break;
	default:
	}

	return CXVisit_Continue;
}

fn doTypedefDecl(ref cursor: CXCursor, w: Walker)
{
	type := clang_getTypedefDeclUnderlyingType(cursor);
	tdName := getVoltString(clang_getCursorSpelling(cursor));

	w.writeIndent();
	writef("alias %s = ", tdName);
	type.printType();
	writefln(";");
}

fn doFunctionDecl(ref cursor: CXCursor, w: Walker)
{
	funcName := getVoltString(clang_getCursorSpelling(cursor));

	w.writeIndent();
	writef("extern(C) fn %s(", funcName);

	count := cast(u32)clang_Cursor_getNumArguments(cursor);
	foreach (i; 0 .. count) {
		if (i > 0) {
			writef(", ");
		}

		arg := clang_Cursor_getArgument(cursor, i);
		argName := getVoltString(clang_getCursorSpelling(arg));

		if (argName !is null) {
			writef("%s : ", argName);
		}
		type := clang_getCursorType(arg);
		type.printType();
	}

	writef(") ");

	type := clang_getCursorType(cursor);
	ret := clang_getResultType(type);
	ret.printType();
	writefln(";");
}

fn doStructDecl(ref cursor: CXCursor, w: Walker)
{
	doAggregateDecl(ref cursor, w, "struct");
}

fn doUnionDecl(ref cursor: CXCursor, w: Walker)
{
	doAggregateDecl(ref cursor, w, "union");
}

fn doAggregateDecl(ref cursor: CXCursor, w: Walker, keyword: string)
{
	structType: CXType;
	clang_getCursorType(out structType, cursor);

	structName := getVoltString(clang_getCursorSpelling(cursor));
	isPrivate := false;

	if (structName == "") {
		idName := getVoltString(clang_getTypeSpelling(structType));
		structName = w.getAnonymousName(idName);
		isPrivate = true;
	}

	w.writeIndent();
	writef("%s %s %s\n", isPrivate ? "private" : "", keyword, structName);
	w.writeIndent();
	writef("{\n");

	w.indent++;
	clang_Type_visitFields(structType, visitFieldAndPrint, cast(void*)w);
	w.indent--;

	w.writeIndent();
	writeln("}");
}

fn doVarDecl(ref cursor: CXCursor, w: Walker)
{
	type: CXType;
	clang_getCursorType(out type, cursor);
	vName := getVoltString(clang_getCursorSpelling(cursor));

	w.writeIndent();
	writef("%s : ", vName);
	type.printType();

	clang_visitChildren(cursor, assignVisitAndPrint, cast(void*)w);

	writefln(";");
}

fn doIntLiteral(ref cursor: CXCursor, w: Walker)
{
	range := clang_getCursorExtent(cursor);
	tokens: CXToken*;
	nTokens: u32;
	clang_tokenize(w.tu, range, &tokens, &nTokens);
	if (nTokens > 0) {
		str := getVoltString(clang_getTokenSpelling(w.tu, tokens[0]));
		write(str);
	}
	clang_disposeTokens(w.tu, tokens, nTokens);
}