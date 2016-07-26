// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/fourier/license.volt (BOOST ver. 1.0).
module fourier.walker;

import watt.io;
import watt.text.format : format;
import watt.math.random : RandomGenerator;
import core.stdc.time : time;

import lib.clang;

import fourier.visit;
import fourier.volt : Base, Parent;
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
	parentStack: Parent[];

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
		parentStack ~= parent;
	}

	fn popAggregate()
	{
		aggregateCursors = aggregateCursors[0 .. $-1];
		anonAggregateVarCounters = anonAggregateVarCounters[0 .. $-1];
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
			parentStack[$-1].children ~= base;
		} else {
			mod ~= base;
		}
	}
}

fn walk(tu: CXTranslationUnit, printDebug: bool, moduleName: string)
{
	w := new Walker(tu, moduleName);
	ptr := cast(void*)w;
	cursor := clang_getTranslationUnitCursor(tu);

	if (printDebug) {
		visit(cursor, CXCursor.init, ptr);
	}

	// Print all top level function decls.
	clang_visitChildren(cursor, visitAndPrint, ptr);

	print(w.mod, moduleName);
}