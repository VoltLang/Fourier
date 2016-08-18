// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/fourier/license.volt (BOOST ver. 1.0).
module fourier.util;

import core.exception : Exception;

import watt.io : writef, write;
import watt.path : baseName, extension;
import watt.text.format : format;

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

fn typeString(type: CXType, walker: Walker, id: string = "") string
{
	isConst := clang_isConstQualifiedType(type);
	fn applyConst(s: string) string
	{
		if (!isConst) {
			return s;
		} else {
			return "const(" ~ s ~ ")";
		}
	}

	switch (type.kind) {
	case CXType_Invalid: throw new Exception("Invalid Type");
	case CXType_FunctionProto, CXType_FunctionNoProto:
		buf: string;
		buf ~= "fn (";
		count := cast(u32)clang_getNumArgTypes(type);

		foreach (i; 0 .. count) {
			if (i > 0) {
				buf ~= ", ";
			}

			arg := clang_getArgType(type, i);
			buf ~= arg.typeString(walker, id);
		}
		buf ~= ") ";

		ret := clang_getResultType(type);
		buf ~= "(";
		buf ~= ret.typeString(walker, id);
		buf ~= ")";
		return applyConst(buf);
	case CXType_Typedef:
		cursor := clang_getTypeDeclaration(type);
		tdName := getVoltString(clang_getCursorSpelling(cursor));
		if (isVaList(tdName)) {
			return applyConst("va_list");
		}
		return applyConst(tdName);
	case CXType_Pointer:
		base: CXType;
		clang_getPointeeType(out base, type);
		if (base.kind == CXType_Unexposed) {
			canonicalType: CXType;
			clang_getCanonicalType(out canonicalType, base);
			if (canonicalType.kind == CXType_FunctionNoProto ||
				canonicalType.kind == CXType_FunctionProto) {
				// Don't print * for function pointers.
				return applyConst(base.typeString(walker, id));
			}
		}
		return applyConst(format("%s*", base.typeString(walker, id)));
	case CXType_IncompleteArray:
		base: CXType;
		clang_getArrayElementType(out base, type);
		return applyConst(format("%s*", base.typeString(walker, id)));
	case CXType_ConstantArray:
		base: CXType;
		clang_getArrayElementType(out base, type);
		sz: i64 = clang_getArraySize(type);
		return applyConst(format("%s[%s]", base.typeString(walker, id), sz));
	case CXType_Record:
		if (id != "" && walker.hasAnonymousName(id)) {
			return applyConst(walker.getAnonymousName(id));
		}
		cursor := clang_getTypeDeclaration(type);
		return applyConst(getVoltString(clang_getCursorSpelling(cursor)));
	case CXType_Unexposed:
		canonicalType: CXType;
		clang_getCanonicalType(out canonicalType, type);
		if (!clang_equalTypes(type, canonicalType)) {
			return typeString(canonicalType, walker, id);
		}
		goto default;
	case CXType_Void: return applyConst("void");
	case CXType_Char_S: return applyConst("char");
	case CXType_Char_U: return applyConst("char");
	case CXType_UChar: return applyConst("u8");
	case CXType_SChar: return applyConst("i8");
	case CXType_UShort: return applyConst("u16");
	case CXType_Short: return applyConst("i16");
	case CXType_UInt: return applyConst("u32");
	case CXType_Int: return applyConst("i32");
	case CXType_ULong: return applyConst("c_ulong");
	case CXType_Long: return applyConst("c_long");
	case CXType_ULongLong: return applyConst("u64");
	case CXType_LongLong: return applyConst("i64");
	case CXType_Bool: return applyConst("bool");
	case CXType_Float: return applyConst("f32");
	case CXType_Double: return applyConst("f64");
	case CXType_LongDouble: return applyConst("f64");
	default: return applyConst(type.kind.toString());
	}
	assert(false);  // Never reached.
}

fn isVaList(decl: string) bool
{
	return decl == "__builtin_va_list";
}
