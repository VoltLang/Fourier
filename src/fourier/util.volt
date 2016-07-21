// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/fourier/license.volt (BOOST ver. 1.0).
module fourier.util;

import watt.io : writef, write;
import watt.path : baseName, extension;

import lib.clang;

import fourier.walker;

/**
 * Get a Volt string from a CXString.
 * This function will dispose the CXString.
 */
fn getVoltString(text : CXString) string
{
	str := clang_getVoltString(text);
	clang_disposeString(text);
	return str;
}

/**
 * Given a path to a C source file or header, return a string
 * usable as a module name.
 */
fn getModuleName(path: string) string
{
	return baseName(path, extension(path));
}

fn printType(type: CXType, walker: Walker, id: string = "")
{
	isConst := clang_isConstQualifiedType(type);
	if (isConst) {
		write("const(");
	}
	switch (type.kind) {
	case CXType_Invalid: return;
	case CXType_FunctionProto, CXType_FunctionNoProto:
		writef("fn (");
		count := cast(u32)clang_getNumArgTypes(type);

		foreach (i; 0 .. count) {
			if (i > 0) {
				writef(", ");
			}

			arg := clang_getArgType(type, i);
			arg.printType(walker, id);
		}
		writef(") ");

		ret := clang_getResultType(type);
		write("(");
		ret.printType(walker, id);
		write(")");
		break;
	case CXType_Typedef:
		cursor := clang_getTypeDeclaration(type);
		tdName := getVoltString(clang_getCursorSpelling(cursor));
		if (isVaList(tdName)) {
			writef("va_list");
		} else {
			writef("%s", tdName);
		}
		break;
	case CXType_Pointer:
		base: CXType;
		clang_getPointeeType(out base, type);
		base.printType(walker, id);
		writef("*");
		break;
	case CXType_IncompleteArray:
		base: CXType;
		clang_getArrayElementType(out base, type);
		base.printType(walker, id);
		writef("*");
		break;
	case CXType_ConstantArray:
		base: CXType;
		clang_getArrayElementType(out base, type);
		sz: i64 = clang_getArraySize(type);
		base.printType(walker, id);
		writef("[%s]", sz);
		break;
	case CXType_Record:
		if (id != "" && walker.hasAnonymousName(id)) {
			write(walker.getAnonymousName(id));
			break;
		}
		cursor := clang_getTypeDeclaration(type);
		write(getVoltString(clang_getCursorSpelling(cursor)));
		break;
	case CXType_Unexposed:
		canonicalType: CXType;
		clang_getCanonicalType(out canonicalType, type);
		if (!clang_equalTypes(type, canonicalType)) {
			printType(canonicalType, walker, id);
			break;
		}
		goto default;
	case CXType_Void: writef("void"); break;
	case CXType_Char_S: writef("char"); break;
	case CXType_Char_U: writef("char"); break;
	case CXType_UChar: writef("u8"); break;
	case CXType_SChar: writef("i8"); break;
	case CXType_UShort: writef("u16"); break;
	case CXType_Short: writef("i16"); break;
	case CXType_UInt: writef("u32"); break;
	case CXType_Int: writef("i32"); break;
	case CXType_ULong: writef("c_long"); break;
	case CXType_Long: writef("c_ulong"); break;
	case CXType_ULongLong: writef("u64"); break;
	case CXType_LongLong: writef("i64"); break;
	case CXType_Bool: writef("bool"); break;
	default: writef("%s", type.kind.toString()); break;
	}
	if (isConst) {
		write(")");
	}
}

fn isVaList(decl: string) bool
{
	return decl == "__builtin_va_list";
}