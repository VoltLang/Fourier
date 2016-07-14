// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/fourier/license.volt (BOOST ver. 1.0).
module main;

import lib.clang;

import watt.conv;
import watt.io;


fn main(args: string[]) i32
{
	test(args.length > 1 ? args[1] : "test/test.c");
	return 0;
}

fn test(file: string)
{
	index := clang_createIndex(0, 0);
	args := ["-I.".ptr];
	tu := clang_parseTranslationUnit(index,
		file.ptr, args.ptr, cast(int)args.length,
		null, 0, CXTranslationUnit_None);

	tu.printDiag(file);
	tu.walk();

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
		info = clang_getVoltString(text);
		clang_disposeString(text);

		output.writefln("%s:%s:%s info %s", file, line, column, info);
	}
}

class Walker
{
	int indent;

	fn writeIndent()
	{
		foreach (0 .. indent) {
			writef("  ");
		}
	}
}

fn walk(tu: CXTranslationUnit)
{
	w := new Walker();
	ptr := cast(void*)w;
	cursor := clang_getTranslationUnitCursor(tu);

	visit(cursor, CXCursor.init, ptr);

	writefln("");

	// Print all top level function decls.
	clang_visitChildren(cursor, visitAndPrint, ptr);
}

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
	default:
	}

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
	tdText := clang_getCursorSpelling(cursor);
	tdName := clang_getVoltString(tdText);
	clang_disposeString(tdText);

	w.writeIndent();
	writef("alias %s = ", tdName);
	type.printType();
	writefln(";");
}

fn doFunctionDecl(ref cursor: CXCursor, w: Walker)
{
	funcText := clang_getCursorSpelling(cursor);
	funcName := clang_getVoltString(funcText);
	clang_disposeString(funcText);

	w.writeIndent();
	writef("extern(C) fn %s(", funcName);

	count := cast(u32)clang_Cursor_getNumArguments(cursor);
	foreach (i; 0 .. count) {
		if (i > 0) {
			writef(", ");
		}

		arg := clang_Cursor_getArgument(cursor, i);
		argText := clang_getCursorSpelling(arg);
		argName := clang_getVoltString(argText);
		clang_disposeString(argText);

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

	structText := clang_getCursorSpelling(cursor);
	structName := clang_getVoltString(structText);
	clang_disposeString(structText);

	w.writeIndent();
	writef("%s %s\n", keyword, structName);
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
	vText := clang_getCursorSpelling(cursor);
	vName := clang_getVoltString(vText);
	clang_disposeString(vText);

	w.writeIndent();
	writef("%s : ", vName);
	type.printType();
	writefln(";");
}

fn printType(type: CXType)
{
	switch (type.kind) {
	case CXType_Invalid: return;
	case CXType_FunctionProto:
		writef("fn (");
		count := cast(u32)clang_getNumArgTypes(type);

		foreach (i; 0 .. count) {
			if (i > 0) {
				writef(", ");
			}

			arg := clang_getArgType(type, i);
			arg.printType();
		}
		writef(") ");

		ret := clang_getResultType(type);
		ret.printType();
		return;
	case CXType_Typedef:
		cursor := clang_getTypeDeclaration(type);
		tdText := clang_getCursorSpelling(cursor);
		tdName := clang_getVoltString(tdText);
		clang_disposeString(tdText);
		writef("%s", tdName);
		return;
	case CXType_Pointer:
		base: CXType;
		clang_getPointeeType(out base, type);
		base.printType();
		writef("*");
		break;
	case CXType_Void: return writef("void");
	case CXType_Char_S: return writef("char");
	case CXType_Char_U: return writef("char");
	case CXType_UChar: return writef("u8");
	case CXType_SChar: return writef("i8");
	case CXType_UShort: return writef("u16");
	case CXType_Short: return writef("i16");
	case CXType_UInt: return writef("u32");
	case CXType_Int: return writef("i32");
	case CXType_ULongLong: return writef("u64");
	case CXType_LongLong: return writef("i64");
	default: writef("%s", type.kind.toString());
	}
}
