// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/fourier/license.volt (BOOST ver. 1.0).
module fourier.json.volt;

import core.exception;
import watt.io.file;
import watt.io : writefln;
import json = watt.text.json;

import fourier.json.errors;
import fourier.json.eval;


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
}

/**
 * Base class for all doc objects.
 */
class Base : Value
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


public:
	override fn ident(n : ir.Node, key : string) Value
	{
		switch (key) {
		case "name": return new Text(name);
		case "doc": return new Text(doc);
		default: throw makeNoField(n, key);
		}
	}
}

/**
 * Base class for things with children, like Module, Class, Structs.
 */
class Parent : Named
{
public:
	children : Value[];


public:
	override fn ident(n : ir.Node,  key : string) Value
	{
		c := Collection.make(children, key);
		if (c !is null) {
			return c;
		}

		switch (key) {
		case "name": return new Text(name);
		case "doc": return new Text(doc);
		case "all": return new Array(children);
		default: throw makeNoField(n, key);
		}
	}
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

/**
 * Return from a function.
 */
class Return : Base
{
	type : string;
	typeFull : string;
}

/**
 * A variable or field on a aggregate.
 */
class Variable : Named
{
	type : string;
	typeFull : string;
}

/**
 * A function or constructor, destructor or method on a aggreegate.
 */
class Function : Named
{
	args : Value[];
	rets : Value[];
}

/**
 * A special array that you can access fields on to filter the members.
 */
class Collection : Array
{
public:
	this(vals : Value[])
	{
		super(vals);
	}

	static fn make(vals : Value[], key : string) Value
	{
		kind : Kind;
		switch (key) with (Kind) {
		case "enums": kind = Enum; break;
		case "classes": kind = Class; break;
		case "unions": kind = Union; break;
		case "structs": kind = Struct; break;
		case "modules": kind = Module; break;
		case "members": kind = Member; break;
		case "functions": kind = Function; break;
		case "variables": kind = Variable; break;
		case "destructors": kind = Destructor; break;
		case "constructors": kind = Constructor; break;
		default: return null;
		}

		num : size_t;
		ret := new Value[](vals.length);
		foreach (v; vals) {
			b := cast(Base)v;
			if (b is null || b.kind != kind) {
				continue;
			}

			ret[num++] = v;
		}

		if (num > 0) {
			return new Collection(ret[0 .. num]);
		} else {
			return new Nil();
		}
	}

	override fn ident(n : ir.Node, key : string) Value
	{
		c := make(vals, key);
		if (c is null) {
			throw makeNoField(n, key);
		} else {
			return c;
		}
	}
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
	children : Value[];
	rets : Value[];
	args : Value[];


public:
	fn getFields(ref e : json.Value)
	{
		foreach (k; e.keys()) {
			v := e.lookupObjectKey(k);
			switch (k) {
			case "doc": this.doc = v.str(); break;
			case "args": args.fromArray(ref v, Kind.Arg); break;
			case "rets": rets.fromArray(ref v, Kind.Arg); break;
			case "name": this.name = v.str(); break;
			case "type": this.type = v.str(); break;
			case "kind": this.kind = getKindFromString(v.str()); break;
			case "typeFull": this.typeFull = v.str(); break;
			case "children": children.fromArray(ref v); break;
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

	fn toFunction() Function
	{
		b := new Function();
		copyToNamed(b);
		b.args = args;
		b.rets = rets;
		switch (kind) with (Kind) {
		case Destructor: b.name = "~this"; break;
		case Constructor: b.name = "this"; break;
		default:
		}
		return b;
	}
}

fn fromArray(ref arr : Value[], ref v : json.Value, defKind : Kind = Kind.Invalid)
{
	foreach (ref e; v.array()) {
		info : Info;
		info.kind = defKind;
		info.getFields(ref e);
		final switch (info.kind) with (Kind) {
		case Invalid: throw new Exception("kind not specified");
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
	default: throw new Exception("unknown kind '" ~ str ~ "'");
	}
}

fn parse(data : string) Value[]
{
	root := json.parse(data);

	mods : Value[];
	mods.fromArray(ref root);

	return mods;
}
