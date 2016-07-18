// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/fourier/license.volt (BOOST ver. 1.0).
module fourier.util;

import watt.io : writef;

import lib.clang;

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
	case CXType_ULong: return writef("c_long");
	case CXType_Long: return writef("c_ulong");
	case CXType_ULongLong: return writef("u64");
	case CXType_LongLong: return writef("i64");
	default: writef("%s", type.kind.toString());
	}
}