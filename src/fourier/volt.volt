// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/fourier/license.volt (BOOST ver. 1.0).
module fourier.volt;

import core.exception;
import watt.conv;
import watt.io.file;
import watt.io : writefln;
import watt.text.string : indexOf, replace, endsWith;
import watt.text.sink;
import json = watt.json;

/*!
 * Type of doc object.
 */
enum Kind
{
	Invalid,
	Arg,
	Enum,
	EnumDecl,
	Class,
	Union,
	Return,
	Struct,
	Module,
	Member,
	Function,
	Variable,
	Destructor,
	Constructor,
	Alias,
	Exp,
	Import,
}

enum Linkage
{
	Volt,
	C,
	Windows,
	CPlusPlus,
	Other,
}

fn stringToLinkage(s: string) Linkage
{
	switch (s) {
	case "c": return Linkage.C;
	case "c++": return Linkage.CPlusPlus;
	case "windows": return Linkage.Windows;
	default: return Linkage.Other;
	}
}

/*!
 * Base class for all doc objects.
 */
class Base
{
	kind : Kind;
	doc : string;
}

/*!
 * Base class for all doc objects that can have names.
 */
class Named : Base
{
public:
	name : string;
}

class EnumDecl : Named
{
public:
	value : int;
}

fn buildEnumDecl(name: string, value: int) EnumDecl
{
	named := new EnumDecl();
	named.kind = Kind.EnumDecl;
	named.name = name;
	named.value = value;
	return named;
}

/*!
 * Base class for things with children, like Module, Class, Structs.
 */
class Parent : Named
{
public:
	children : Base[];
	isAnonymous : bool;  // If this was generated from C, does this have a generated name?
}

fn buildAggregate(kind: Kind, name: string, children: Base[]) Parent
{
	assert(kind == Kind.Struct || kind == Kind.Union);
	parent := new Parent();
	parent.kind = kind;
	parent.name = name;
	parent.children = children;
	return parent;
}

fn buildStruct(name: string) Parent
{
	return buildAggregate(Kind.Struct, name, null);
}

/*!
 * Common base class for typed things.
 */
class Typed : Base
{
	type : string;
	typeFull : string;
}

/*!
 * Argument to a function.
 */
class Arg : Typed
{
	name : string;
}

fn buildArg(name: string, type: string) Arg
{
	arg := new Arg();
	arg.name = name;
	arg.type = type;
	return arg;
}

/*!
 * Return from a function.
 */
class Return : Typed
{
	// Empty
}

fn buildReturn(type: string) Return
{
	ret := new Return();
	ret.kind = Kind.Return;
	ret.type = type;
	return ret;
}

/*!
 * A variable or field on a aggregate.
 */
class Variable : Named
{
	type : string;
	typeFull : string;
	assign : Base;

	isGlobal : bool;
}

fn buildVariable(name: string, type: string) Variable
{
	var := new Variable();
	var.kind = Kind.Variable;
	var.name = name;
	var.type = type;
	return var;
}

/*!
 * An alias.
 */
class Alias : Named
{
	type : string;
	typeFull : string;
}

fn buildAlias(name: string, type: string) Alias
{
	_alias := new Alias();
	_alias.kind = Kind.Alias;
	_alias.name = name;
	_alias.type = type;
	return _alias;
}

/*!
 * A function or constructor, destructor or method on a aggregate.
 */
class Function : Named
{
	args : Base[];
	rets : Base[];
	linkage : Linkage;
	hasBody : bool;
}

fn buildFunction(name: string, args: Base[], rets: Base[]) Function
{
	func := new Function();
	func.kind = Kind.Function;
	func.name = name;
	func.args = args;
	func.rets = rets;
	return func;
}

/*!
 * An expression.
 */
class Exp : Base
{
public:
	value : string;
}

fn buildExp(value: string) Exp
{
	exp := new Exp();
	exp.kind = Kind.Exp;
	exp.value = value;
	return exp;
}

/*!
 * Given a string 'const(const(T))', turn it into 'const(T)'.
 * The outer const is stripped, so const(const(T)*) becomes const(T)*.
 */
fn compressConst(s: string) string
{
	/* The problem is, without involving a parser, that we can get fn (const(const(void)*)),
	 * so a simple replace will shave off the closing paren of the function parameter definition.
	 * Thus this horrific piece of code, that does a replace while checking for that case.
	 */
	if (s.indexOf("const(const(") != -1) {
		s = s.replace("const(const(", "const(");
		i := s.indexOf(")*)");
		while (i != -1 && s.indexOf(")*) (") == -1) {
			si := cast(size_t) i;
			StringSink ss;
			ss.sink(s[0 .. si+")*".length]);
			ss.sink(s[si+")*)".length .. $]);
			s = ss.toString();
			i = s.indexOf(")*)");
		}
		s = s.replace("*)*", ")**");
		if (s.endsWith("*)")) {
			s = s[0 .. $-1];
		}
		return s;
	}
	if (s.endsWith("*)")) {
		s = s.replace("*)", ")*");
	}
	return s;
}

/*!
 * Used to collect information during parsing.
 */
struct Info
{
public:
	kind : Kind;
	name : string;
	doc : string;
	type : string;
	typeFull : string;
	children : Base[];
	rets : Base[];
	args : Base[];
	linkage : Linkage;
	hasBody : bool;
	value : string;


public:
	fn getFields(ref e : json.Value)
	{
		linkage = Linkage.Volt;
		foreach (k; e.keys()) {
			v := e.lookupObjectKey(k);
			switch (k) {
			case "doc": this.doc = v.str(); break;
			case "args": args.fromArray(ref v, Kind.Arg); break;
			case "rets": rets.fromArray(ref v, Kind.Return); break;
			case "name": this.name = v.str(); break;
			case "type": this.type = compressConst(v.str()); break;
			case "kind": this.kind = getKindFromString(v.str()); break;
			case "typeFull": this.typeFull = v.str(); break;
			case "children": children.fromArray(ref v); break;
			case "linkage": this.linkage = stringToLinkage(v.str()); break;
			case "hasBody": this.hasBody = v.boolean(); break;
			case "value": this.value = v.str(); break;
			case "access", "isStandalone", "storage", "mangledName", "isExtern", "aliases":
				break; // silenced
			default: writefln("unknown key '" ~ k ~ "'");
			}
		}
	}

	fn copyToBase(b : Base )
	{
		b.kind = kind;
		b.doc = doc;
	}

	fn copyToNamed(b : Named)
	{
		copyToBase(b);
		b.name = name;
	}

	fn copyToParent(b : Parent)
	{
		copyToNamed(b);
		b.isAnonymous = b.name.indexOf("__Anon") >= 0;
		b.children = children;
	}

	fn toParent() Parent
	{
		b := new Parent();
		copyToParent(b);
		return b;
	}

	fn toNamed() Named
	{
		b := new Named();
		copyToNamed(b);
		return b;
	}

	fn toArg() Arg
	{
		b := new Arg();
		b.doc = doc;
		b.name = name;
		b.type = type;
		b.typeFull = typeFull;
		return b;
	}

	fn toReturn() Return
	{
		b := new Return();
		copyToBase(b);
		b.type = type;
		b.typeFull = typeFull;
		return b;
	}

	fn toVariable() Variable
	{
		b := new Variable();
		copyToNamed(b);
		b.type = type;
		b.typeFull = typeFull;
		return b;
	}

	fn toEnumDecl() EnumDecl
	{
		b := new EnumDecl();
		copyToNamed(b);
		b.kind = Kind.EnumDecl;
		if (value.length > 0) {
			b.value = toInt(value);
		}
		return b;
	}

	fn toAlias() Alias
	{
		b := new Alias();
		copyToNamed(b);
		b.kind = Kind.Alias;
		b.type = type;
		return b;
	}

	fn toFunction() Function
	{
		b := new Function();
		copyToNamed(b);
		b.args = args;
		b.rets = rets;
		b.linkage = linkage;
		b.hasBody = hasBody;
		switch (kind) with (Kind) {
		case Destructor: b.name = "~this"; break;
		case Constructor: b.name = "this"; break;
		default:
		}
		return b;
	}
}

fn fromArray(ref arr : Base[], ref v : json.Value, defKind : Kind = Kind.Invalid)
{
	foreach (ref e; v.array()) {
		info : Info;
		info.kind = defKind;
		info.getFields(ref e);
		final switch (info.kind) with (Kind) {
		case Invalid, Exp: throw new Exception("kind not specified");
		case Alias: arr ~= info.toAlias(); break;
		case Arg: arr ~= info.toArg(); break;
		case Enum: arr ~= info.toNamed(); break;
		case EnumDecl: arr ~= info.toEnumDecl(); break;
		case Class: arr ~= info.toParent(); break;
		case Union: arr ~= info.toParent(); break;
		case Return: arr ~= info.toReturn(); break;
		case Struct: arr ~= info.toParent(); break;
		case Module: arr ~= info.toParent(); break;
		case Member: arr ~= info.toFunction(); break;
		case Variable: arr ~= info.toVariable(); break;
		case Function: arr ~= info.toFunction(); break;
		case Destructor: arr ~= info.toFunction(); break;
		case Constructor: arr ~= info.toFunction(); break;
		case Import: break;
		}
	}
}

fn getKindFromString(str : string) Kind
{
	switch (str) with (Kind) {
	case "fn": return Function;
	case "var": return Variable;
	case "ctor": return Constructor;
	case "dtor": return Destructor;
	case "enum": return Enum;
	case "enumdecl": return EnumDecl;
	case "class": return Class;
	case "union": return Union;
	case "struct": return Struct;
	case "module": return Module;
	case "member": return Member;
	case "alias": return Alias;
	case "import": return Import;
	default: throw new Exception("unknown kind '" ~ str ~ "'");
	}
}

fn getStringFromKind(kind: Kind) string
{
	final switch (kind) with (Kind) {
	case Invalid: return "invalid";
	case Arg: return "arg";
	case Enum: return "enum";
	case EnumDecl: return "enumdecl";
	case Class: return "class";
	case Union: return "union";
	case Return: return "return";
	case Struct: return "struct";
	case Module: return "module";
	case Member: return "member";
	case Function: return "function";
	case Variable: return "variable";
	case Destructor: return "destructor";
	case Constructor: return "constructor";
	case Alias: return "alias";
	case Exp: return "exp";
	case Import: return "import";
	}
}

fn parse(data : string) Base[]
{
	root := json.parse(data);
	modulesRoot := root.lookupObjectKey("modules");

	mods : Base[];
	mods.fromArray(ref modulesRoot);

	return mods;
}
