Fourier
===

Fourier generates and validates C bindings.



Tests
===

Symbols (types, functions, etc) that are defined by the C module,
are checked against those defined in the Volt bindings. Not only
in existence, but in semantics.



Failures
---

###### Function Definition Failures

The type of a function varies between the header
and the Volt module.

```
// Volt
fn fopen(int) FILE*;

// C
FILE* fopen(const char *, const char *);
```

###### Struct Definition Failures

The layout of a struct varies between the header and
the Volt module. In the following case, the first field's size is
incorrect, and the second field has the wrong signedness.

```
// Volt
struct Foo
{
	foo: i32;
	bar: i32;
}

// C
typedef struct {
	int64_t foo;
	uint32_t bar;
}
```

###### Extra Volt Define Failure

The Volt module defines a function that the header does not.

```
// Volt
// lconv not defined.

// C
int lconv(...);
```



Warnings
---

###### Extra Header Function Warning

The header defines a function that the Volt module does not.

```
// Volt
fn lconv(...) i32;

// C
// lconv not supported.
```



Suggestions
---

###### Extra Volt Struct Suggestion

Volt defines struct(s) that the header does not.

```
// Volt
struct Foo {}

// C
// Foo not defined
```
