Fourier
===

Fourier is tool to help generate and check bindings against C libraries.



Tests
===

The symbols are check against each other.



Failures
---

###### Function definitions

If the type of a function is different between the header
and the Volt module.

```
// Volt
fn fopen(int) FILE*;

// C
FILE* fopen(const char *, const char *);
```

###### Struct definitions

If the layout of a struct is different between the header and
the Volt module. In the below case, the first fields size is
wrong, and the second field has the wrong signed ness.

```
// Volt
struct Foo
{
	int foo;
	int bar;
}

// C
typedef struct {
	int64_t foo;
	uint32_t bar;
}
```

###### Extra Volt defines

If the Volt module define a function that the header does not define.

```
// Volt
// lconv not defined.

// C
int lconv(...);
```



Warnings
---

###### Extra header functions

If the header define a function that the Volt module does not define.

```
// Volt
fn lconv(...) i32;

// C
// lconv not supported.
```



Silenced optional
---

###### Extra Volt structs

If volt defines structs that the header does not.

```
// Volt
struct Foo {}

// C
// Foo not defined
```
