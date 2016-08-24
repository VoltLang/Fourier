// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/fourier/license.volt (BOOST ver. 1.0).
module fourier.print;

import watt.io;

import fourier.volt;

/**
 * Given an array of fourier.volt.Bases, print them to stdout as a Volt module.
 */
fn print(bases: Base[], moduleName: string)
{
	printTop(moduleName);
	indent: i32;
	printBases(bases, ref indent);
}

private:

fn printTop(moduleName: string)
{
	writefln("module %s;", moduleName);
	// TODO: Dynamically determine when these are needed.
	writeln("import watt.varargs;");
	writeln("import core.stdc.config;\n");
}

fn printBases(bases: Base[], ref indent: i32)
{
	foreach (base; bases) {
		printBase(base, ref indent);
		writeln("");
	}
}

fn printIndent(indent: i32)
{
	foreach (0 .. indent) {
		write("  ");
	}
}

fn printBase(base: Base, ref indent: i32)
{
	final switch (base.kind) with (Kind) {
	case Invalid: writef("INVALID"); break;
	case Arg: printArg(base, ref indent); break;
	case EnumDecl: printEnumDecl(base, ref indent); break;
	case Enum: printEnum(base, ref indent); break;
	case Class: printClass(base, ref indent); break;
	case Union: printUnion(base, ref indent); break;
	case Return: printReturn(base, ref indent); break;
	case Struct: printStruct(base, ref indent); break;
	case Module: printModule(base, ref indent); break;
	case Member: printMember(base, ref indent); break;
	case Function: printFunction(base, ref indent); break;
	case Variable: printVariable(base, ref indent); break;
	case Destructor: printDestructor(base, ref indent); break;
	case Constructor: printConstructor(base, ref indent); break;
	case Alias: printAlias(base, ref indent); break;
	case Exp: printExp(base, ref indent); break;
	}
}

fn printExp(base: Base, ref indent: i32)
{
	exp := cast(Exp)base;
	assert(exp !is null);
	printIndent(indent);
	write(exp.value);
}

fn printArg(base: Base, ref indent: i32)
{
	arg := cast(Arg)base;
	assert(arg !is null);

	if (arg.name != "") {
		writef("%s : %s", arg.name, arg.type);
	} else {
		writef("%s", arg.type);
	}
}

fn printEnumDecl(base: Base, ref indent: i32)
{
	e := cast(EnumDecl)base;
	assert(e !is null);
	writef("enum %s = %s;", e.name, e.value);
}

fn printVariable(base: Base, ref indent: i32)
{
	v := cast(Variable)base;
	assert(v !is null);
	printIndent(indent);
	writef("%s%s : %s", v.isGlobal ? "global " : "", v.name, v.type);
	if (v.assign !is null) {
		writef(" = ");
		noIndent: i32;
		printBase(v.assign, ref noIndent);
	}
	writef(";");
}

fn printDestructor(base: Base, ref indent: i32)
{
	printIndent(indent);
	write("~this()");
}

fn printConstructor(base: Base, ref indent: i32)
{
	printIndent(indent);
	write("this()");
}

fn printAlias(base: Base, ref indent: i32)
{
	als := cast(Alias)base;
	assert(als !is null);
	printIndent(indent);
	writef("alias %s = %s;", als.name, als.type);	
}

fn printEnum(base: Base, ref indent: i32)
{
	printParent(base, "enum", ref indent);
}

fn printClass(base: Base, ref indent: i32)
{
	printParent(base, "class", ref indent);
}

fn printUnion(base: Base, ref indent: i32)
{
	printParent(base, "union", ref indent);
}

fn printStruct(base: Base, ref indent: i32)
{
	printParent(base, "struct", ref indent);
}


fn printParent(base: Base, keyword: string, ref indent: i32)
{
	p := cast(Parent)base;
	assert(p !is null);

	printIndent(indent);
	writefln("%s%s %s", p.isAnonymous ? "private " : "", keyword, p.name);
	printIndent(indent);
	writefln("{");
	indent++;
	printBases(p.children, ref indent);
	indent--;
	printIndent(indent);
	writef("}");
}

fn printReturn(base: Base, ref indent: i32)
{
	ret := cast(Return)base;
	assert(ret !is null);
	write(ret.type);
}

fn printModule(base: Base, ref indent: i32)
{
	assert(false);
}

fn printFunction(base: Base, ref indent: i32)
{
	func := cast(Function)base;
	assert(func !is null);

	printIndent(indent);
	writef("extern(C) fn %s(", func.name);
	foreach (i, arg; func.args) {
		printArg(arg, ref indent);
		if (i < func.args.length - 1) {
			write(", ");
		}
	}
	write(") (");
	foreach (i, ret; func.rets) {
		printReturn(ret, ref indent);
		if (i < func.rets.length - 1) {
			write(", ");
		}
	}
	write(");");
}

fn printMember(base: Base, ref indent: i32)
{
	printFunction(base, ref indent);
}
