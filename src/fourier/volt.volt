// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/fourier/license.volt (BOOST ver. 1.0).
module fourier.volt;

import core.exception;
import watt.io.file;
import watt.io : writefln;
import watt.text.string : indexOf;
import json = watt.text.json;

/**
 * Type of doc object.
 */
enum Kind
{
	Invalid,
	Arg,
	Enum,
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

/**
 * Base class for all doc objects.
 */
class Base
{
	kind : Kind;
	doc : string;
}

/**
 * Base class for all doc objects that can have names.
 */
class Named : Base
{
public:
	name : string;
}

/**
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
	return buildAggregate(Kind.Struct, name, []);
}

/**
 * Argument to a function.
 */
class Arg : Base
{
	name : string;
	type : string;
	typeFull : string;
}

fn buildArg(name: string, type: string) Arg
{
	arg := new Arg();
	arg.name = name;
	arg.type = type;
	return arg;
}

/**
 * Return from a function.
 */
class Return : Base
{
	type : string;
	typeFull : string;
}

fn buildReturn(type: string) Return
{
	ret := new Return();
	ret.kind = Kind.Return;
	ret.type = type;
	return ret;
}

/**
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

/**
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

/**
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

/**
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

/**
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
			case "type": this.type = v.str(); break;
			case "kind": this.kind = getKindFromString(v.str()); break;
			case "typeFull": this.typeFull = v.str(); break;
			case "children": children.fromArray(ref v); break;
			case "linkage": this.linkage = stringToLinkage(v.str()); break;
			case "hasBody": this.hasBody = v.boolean(); break;
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
	case "class": return Class;
	case "union": return Union;
	case "struct": return Struct;
	case "module": return Module;
	case "member": return Member;
	case "alias": return Alias;
	default: throw new Exception("unknown kind '" ~ str ~ "'");
	}
}

fn getStringFromKind(kind: Kind) string
{
	final switch (kind) with (Kind) {
	case Invalid: return "Invalid";
	case Arg: return "Arg";
	case Enum: return "Enum";
	case Class: return "Class";
	case Union: return "Union";
	case Return: return "Return";
	case Struct: return "Struct";
	case Module: return "Module";
	case Member: return "Member";
	case Function: return "Function";
	case Variable: return "Variable";
	case Destructor: return "Destructor";
	case Constructor: return "Constructor";
	case Alias: return "Alias";
	case Exp: return "Exp";
	}
}

fn parse(data : string) Base[]
{
	root := json.parse(data);

	mods : Base[];
	mods.fromArray(ref root);

	return mods;
}
