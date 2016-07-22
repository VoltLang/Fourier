// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/fourier/license.volt (BOOST ver. 1.0).
module fourier.json.errors;

import core.exception;
import watt.text.source;
import watt.text.format : format;
import ir = fourier.json.ir;


class FourierJsonException : Exception
{
	this(msg : string)
	{
		super(msg);
	}
}


/*
 *
 * Specific Exceptions.
 *
 */

fn makeNoExtension(file : string) FourierJsonException
{
	str := format("error: no file extension '%s'", file);
	return new FourierJsonException(str);
}

fn makeExtensionNotSupported(file : string) FourierJsonException
{
	str := format("error: file extension not supported '%s'", file);
	return new FourierJsonException(str);
}

fn makeLayoutNotFound(file : string, layout : string) FourierJsonException
{
	str := format("%s:1 error: layout '%s' not found", file, layout);
	return new FourierJsonException(str);
}

fn makeConversionNotSupported(layout : string, contents : string) FourierJsonException
{
	str := format("%s:1 error: can not convert '%s' -> '%s'",
	                  contents, contents, layout);
	return new FourierJsonException(str);
}

fn makeBadHeader(ref loc : Location) FourierJsonException
{
	return new FourierJsonException(loc.toString() ~ "error: invalid header");
}


/*
 *
 * Eval Exceptions
 *
 */

class EvalException : FourierJsonException
{
public:
	n : ir.Node;


public:
	this(n : ir.Node, msg : string)
	{
		super(msg);
	}
}

fn makeNoField(n : ir.Node, key : string) EvalException
{
	return new EvalException(n, "no field named '" ~ key ~ "'");
}

fn makeNotSet(n : ir.Node) EvalException
{
	return new EvalException(n, "value is not a set");
}

fn makeNotText(n : ir.Node) EvalException
{
	return new EvalException(n, "value is not text (or convertable)");
}

fn makeNotArray(n : ir.Node) EvalException
{
	return new EvalException(n, "value is not an array");
}
