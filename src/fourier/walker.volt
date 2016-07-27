// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/fourier/license.volt (BOOST ver. 1.0).
module fourier.walker;

import watt.io;
import watt.text.format : format;
import watt.math.random : RandomGenerator;
import core.stdc.time : time;

import lib.clang;

import fourier.visit;
import fourier.volt : Base, Parent, Variable;
import fourier.print : print;

class Walker
{
	tu: CXTranslationUnit;
	mod: Base[];
	moduleName: string;
	random: RandomGenerator;
	names: string[string];
	delayedAggregates: CXCursor[string];
	anonAggregateVarCounters: i32[];
	aggregateCursors: CXCursor[];
	parentStack: Base[];

	indent: i32;

	this(tu: CXTranslationUnit, moduleName: string)
	{
		this.tu = tu;
		this.moduleName = moduleName;
		random.seed(cast(u32)time(null));
	}

	fn writeIndent()
	{
		foreach (0 .. indent) {
			writef("  ");
		}
	}

	/// Returns true if an anonymous name has been set for id.
	fn hasAnonymousName(id: string) bool
	{
		return (id in names) !is null;
	}

	fn getAnonymousName(id: string) string
	{
		if (p := id in names) {
			return *p;
		}
		names[id] = format("__%sAnon%s", id, random.randomString(6));
		return names[id];
	}

	/**
	 * Call before visiting the fields of an aggregate.
	 */
	fn pushAggregate(cursor: CXCursor, parent: Parent)
	{
		aggregateCursors ~= cursor;
		anonAggregateVarCounters ~= 0;
		pushBase(parent);
	}

	fn popAggregate()
	{
		aggregateCursors = aggregateCursors[0 .. $-1];
		anonAggregateVarCounters = anonAggregateVarCounters[0 .. $-1];
		popBase();
	}

	fn pushBase(base: Base)
	{
		parentStack ~= base;
	}

	fn popBase()
	{
		parentStack = parentStack[0 .. $-1];
	}

	/**
	 * Get a variable name for an anonymous struct/union entry.
	 * Must be called after pushAggregate().
	 */
	fn getAnonymousAggregateVarName(prefix: string) string
	{
		i := anonAggregateVarCounters[$-1]++;
		return format("%s%s", prefix, i);
	}

	fn delayAggregate(declarationLine: string, cursor: CXCursor)
	{
		delayedAggregates[declarationLine] = cursor;
	}

	fn isGlobal() bool
	{
		return anonAggregateVarCounters.length == 0;
	}

	fn addBase(base: Base)
	{
		if (parentStack.length > 0) {
			var := cast(Variable)parentStack[$-1];
			if (var !is null) {
				var.assign = base;
			} else {
				p := cast(Parent)parentStack[$-1];
				assert(p !is null);
				p.children ~= base;
			}
		} else {
			mod ~= base;
		}
	}
}

fn walkAndPrint(tu: CXTranslationUnit, printDebug: bool, moduleName: string)
{
	w := walk(tu, printDebug, moduleName);
	print(w.mod, moduleName);
}

fn walk(tu: CXTranslationUnit, printDebug: bool, moduleName: string) Walker
{
	w := new Walker(tu, moduleName);
	ptr := cast(void*)w;
	cursor := clang_getTranslationUnitCursor(tu);

	if (printDebug) {
		visit(cursor, CXCursor.init, ptr);
	}

	// Print all top level function decls.
	clang_visitChildren(cursor, visitAndPrint, ptr);

	return w;
}