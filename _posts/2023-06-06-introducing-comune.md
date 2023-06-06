---
title: introducing the comune programming language
layout: post
image: /assets/images/blog/pepesilvia.png
author: ash
---

so for the better part of a year, i've been working on a little side project: my personal semi-hobbyist take on the "C++ successor language" trend that's emerged over the past couple years, named [comune](https://github.com/comune-lang/comune). 

i'm pretty proud of the progress it's made, but admittedly, my attempts to write up proper documentation have never gotten very far. so for the first blog post on my fancy new hand-rolled site, i thought i'd try and provide a general overview of the goals, design, and implementation of comune.

going over every part of the language in one post would take ages, and i don't have that kind of attention span, but if there's interest for it, i'd be happy to take a more in-depth look at specific features in future blog posts. 

## motivation

where?!

oh, you mean behind the language. right.

over the past year or two, it's become increasingly clear that C++ is simply not fit for purpose anymore (if it ever was). the rise of languages like Rust demonstrates a growing need for stronger safety guarantees and more reliable tooling. and while Rust is an innovative and respectable language in its own right, it has considerable shortcomings of its own that weaken its ability to challenge C++.

to be clear: as a former C++ evangelist, i think Rust is great, and nowadays i use it wherever possible - but i feel it's held back by some of its early design decisions, as well as being unnecessarily complex in places. it does sometimes leave me yearning for the "anything goes" mentality of C++ - even if Rust is significantly more reliable and user-friendly in the long run.

there've been a lot of attempts to replace C++, but none so far have really grabbed me. [Carbon](https://github.com/carbon-language/carbon-lang) doesn't really do it for me; the more i read into it, the more arbitrary its design decisions feel. no disrespect to the people working on it, of course - i'm sure they're far more experienced in the field than i am - but for me, it just doesn't really come together into something i can get excited about. 

it's a similar story for the other endeavours. maybe it's just me being stubborn (i'm pretty sure Carbon got announced just weeks after i had the initial idea for comune, lol) but i still felt motivated to give it a shot myself.

so around july of 2022, i started messing around with some design concepts i'd been cooking up. while i've messed around with writing simple parsers and interpreters, i'd never written a full-on compiler before - it seemed like a fun challenge! i decided i'd just get started and see how far i could get.

and well, i still haven't stopped! somehow!!!

i've learned a lot of things about language design and implementation in that time, and after a lot of experimentation and deliberation (and regular input from [Stelle](https://twitter.com/lostkagamine), who plans to work on the standard library), i think we're honing in on something pretty neat here. and while it's not at all stable yet, i'm very happy with how much progress has been made. 

but hey, i'm getting ahead of myself. let's go over what comune actually *is*:

## overview

comune is a compiled, general-purpose programming language with a focus on performance, ergonomics, safety and C++ interop. it offers features like the following:

- a clean, expression-based syntax, styled after C++, but with the fat trimmed
- parametric polymorphism through traits
- support for function overloads and specialization
- first-class tuples and sum types
- a simple, flexible module system
- static memory safety (with an `unsafe` escape hatch)
- move semantics, with limited support for borrowchecked "shared-xor-mutable" references
- support for "open" and "closed" polymorphism, through classes and structs/enums
- Rust-style "dynamic drop" semantics

the current compiler implementation is written in Rust, with no immediate plans to self-host (trust me, i've got enough work on my plate as-is), and it offers very respectable compilation times (so far) thanks to a highly concurrency-oriented architecture.

but this is all pretty abstract so far. let's go over some actual code, shall we?

## some actual code

{% codelog code %}

```cpp
@no_mangle
int printf(u8* fmt, ...);

int main() {
	printf(c"Hello world!\n");
}
```
{% endcodelog %}

(side note: i'm aware the syntax highlighting is butt-ugly. i'll get around to fixing it one of these days)

here's your basic Hello World. note that at time of writing, there's no real standard library yet - but we don't need one! the compiler links `libc` by default, so we can use good old `printf` no problem. note that the `int` type here is just an alias for `i32` - comune's basic types all have clearly-defined sizes.

but hey, what's that `c` prefix before the string literal about? well, comune's string literals are of type `u8[]`, not `u8*`. let's remove it and see what happens:

![error: no viable overload found for printf(u8[dyn]) - in main.co:5:2](/assets/images/blog/comune_err_0.png)

(and yep, i *am* really proud of the error message formatting!)

the problem here is that comune's built-in strings are *slices*, AKA pointers with length metadata attached to them (note that unlike Rust, comune doesn't have a special UTF-8-enforced `str` type - although the planned standard library `String` type is UTF-8-enabled, and the language's string literals use it as well)

since these slices carry the length with them, they aren't null-terminated - which is a problem for C/C++ code that does expect it. so if you want a C-compatible string literal, you use the `c` prefix to create a null-terminated `u8*` (aka `const char*`).

...wow, we've just spent a couple hundred words talking about Hello World, haven't we? i may have underestimated how much there is to go over. let's speed things up a little with some basic variable and expression syntax:

{% codelog code %}
```cpp
int main() {
	// variable bindings are immutable by default
	int mut a = 1;
	a = 2;

	// control flow is expression-based,
	// and blocks can have results
	int b = if true {
		1
	} else {
		2
	};
	
	// deferred initialization is allowed, and the
	// compiler statically enforces init-before-use
	int c;

	// side note: putting semicolons after block expressions,
	// while not required, is still good practice, because if
	// you start the next statement with a pointer dereference,
	// the parser will misinterpret it as a multiply operator.

	if true {
		c = 3;
	};

	// error: use of potentially uninitialized variable `c`
	foo(c)
}
```
{% endcodelog %}

### variable bindings and references

comune - shocker - takes after Rust for its concept of variable bindings, with one notable difference: in comune, references are a *kind of variable binding*, rather than a distinct type.

the syntax for references looks like this:

{% codelog code %}
```cpp
void foo(int& a); // shared reference parameter
void foo(int mut& a); // mutable reference parameter
```
{% endcodelog %}

in this sense, they're closer to C++ references than Rust ones; they're fully transparent, must be immediately initialized, and can't be rebound. however, they still provide all the safety guarantees Rust does, and they do have a simple form of lifetimes - but that topic might be worthy of its own blog post.

here's a summary of the kind of references comune supports, and their safety guarantees (subject to change):

#### `T&`, the shared reference

the shared reference is comune's equivalent to Rust's `&T`, and provides essentially the same guarantees:

- the referenced data is aligned, allocated and initialized
- the referenced memory will ***not be mutated*** while the reference exists

#### `T mut&`, the unique reference

similarly, `T mut&` is comune's `&mut T`, and provides the following guarantees:

- the referenced data is aligned, allocated and initialized
- the referenced memory will ***not be aliased*** while the reference exists

#### `T new&`, the initializing reference

`T new&` is a special kind of reference used in constructors. it mostly behaves like a `T mut&`, with one major distinction: **the data pointed to by a `T new&` is treated as logically uninitialized.**

in essence, the initializing reference is a "write-only" reference - at least, until it's been written to at least once. once the referenced data has been properly initialized, the reference becomes functionally identical to a `T mut&`.

## anyway let's talk about types

comune's type system is pretty powerful. real quick, here's every kind of type in the language:

- basic types (`int`, `float`, etc)
- pointers (`T*`, `T mut*`)
- function pointers (i.e. `void(int,int)*`)
- arrays (`T[n]`)
- slices (`T[]`)
- "product" tuples (`(T, U, V)`)
- "sum" tuples (`(T | U | V)`)
- the newtype (`(T)`)
- the void type (`void`)
- the never type (`never`)
- classes, with inheritance
- structs/enums, without inheritance

that's quite a list! some of these are pretty obvious, but others deserve some elaboration.

### sum tuples

"sum tuples" are my probably-technically-incorrect nickname for comune's structural sum type. sum types are like `union`s in C++ and `enum`s in Rust, in that they represent "one of the above", in contrast to product types (i.e. `struct`s) which represent "all of the above".

for instance, a type `(int | float)` is either an int *or* a float. to find out which it is, we can use `match`:

{% codelog code %}
```cpp
// where `my_sum_tuple` is of type (int | float)
match my_sum_tuple {
	int i => printf(c"It's an int!: %i\n", i),

	float f => printf(c"It's a float!: %f\n", f),
};
```
{% endcodelog %}

### the newtype
the newtype is a transparent wrapper over an existing type. it can be used to discern between values with different purposes that nonetheless all share the same underlying type. a typical example is preventing mixups between a Days type and a Years type:

{% codelog code %}
```cpp
type Days(u32);
type Years(u32);

// You can write impls on newtypes, 
// "overriding" the underlying type's impls

impl Days {
	Years to_years(&self) {
		Years(self / 365)
	}
}

bool old_enough(Years& age) {
	age >= 10
}

```
{% endcodelog %}

logically, creating a newtype can be considered a limited form of inheritance. the newtype inherits all the impls of the base type, while allowing the user to statically override them.

(worth noting: i have some unresolved concerns about the soundness of this concept, so don't consider it set in stone. I Just Think They're Neat)

### the never type 
`never` is the type of an expression that never completes. this is roughly equivalent to `noreturn` in C++, and ironically, it's the type of the `return` expression (because any code after a `return` never gets executed!)

the `never` type coerces to every other type, because can never produce a wrong value. this has some really nice ergonomic effects, like letting you put a `return` anywhere and having it easily typecheck. in type theory, this is known as the [bottom type](https://en.wikipedia.org/wiki/Bottom_type), but i am NOT calling it that are you CRAZY

### classes/structs/enums

if you're reading this i hope to god you know what structs, classes and enums are.

structs are your typical product type. you define struct bodies with typical C-style syntax, and their methods inside `impl` blocks. pretty straight-forward!

classes are A Planned Feature, mostly for C++ compatibility, but also because they possess genuinely useful capabilities that i'd like the language to have. but yeah, this feature isn't really fleshed out whatsoever, don't @ me

and enums are the spiciest of all. if you know Rust, these'll be familiar to you, but there's still some surprises in store.

{% codelog code %}
```cpp
// Enums can have payloads, making them
// the nominal equivalent to "sum tuples"
enum MyCoolEnum {
	VariantA(u16, u16),
	VariantB(u32),
}

// WHUH?????????????????????
int sum_variant_a(MyCoolEnum::VariantA& variant) {
	variant.0 + variant.1
}
```
{% endcodelog %}
THAT'S RIGHT BABY!!!! EVERY ENUM VARIANT IS A TYPE IN ITS OWN RIGHT!!!! GOd am i proud of this feature.

can you tell i've been writing this post for hours on end? anyway yeah final note: unlike Rust, user-defined types have support for both constructors and destructors, with the following syntax:

{% codelog code %}
```cpp
struct MyCoolStruct {
	int a;
	int b;

	// note that unlike regular methods,
	// these are defined in the type body.
	// this is mostly for annoying technical reasons.

	// `new&` is a special kind of binding,
	// letting you safely handle uninitialized data
	new(new& self, int a, int b) {
		self.a = a;
		self.b = b;
	}

	drop(mut& self) {
		printf(c"MyCoolType has been dropped!\n");
	}
}

int main() {
	// `new` is just the constructor keyword,
	// it doesn't imply dynamic allocation
	MyCoolStruct a = new MyCoolStruct(0, 0);
	
	// If you have access to all the fields,
	// you can also use a literal constructor
	MyCoolStruct b = new MyCoolStruct {
		a: 0,
		b: 0,
	};

	// You can even perform in-place construction!
	MyCoolStruct c;

	new (c) MyCoolStruct(0, 0);
}
```
{% endcodelog %}


## generics and traits

one of the primary motivations behind the creation of comune was to improve upon Rust's generics and traits in terms of flexibility. [specialization](https://github.com/rust-lang/rfcs/pull/1210), for instance, is a long-requested feature that Rust has so far been unable to stabilize, largely due to technical issues and poor interactions with other language features leading to unsoundness. one of my main goals is to ~~blow up~~ take the foundation that Rust's generics laid out, and expand upon them to approach the flexibility of C++'s templates.

The basic generics syntax is as follows:

{% codelog code %}
```cpp
// Generics can be used in the return type, 
// even before their declaration
T foo<type T>();

struct GenericStruct<type T> {
	T cool_generic_member;
}

impl<type T> GenericStruct<T> {

	T& get(&self) {
		self.cool_generic_member
	}
}

```
{% endcodelog %}

## miscellanea
here's some cool stuff i couldn't naturally fit in anywhere else:

- declarations are order-independent, as they damn well oughta be

- after a long, gruelling fight, comune's [turbofish](https://turbo.fish/) has been struck down. when encountering the relevant syntactic ambiguity (i.e. `(a<b, c>(d))`), the parser will default to disambiguating it as a generic function call; if you meant to write a tuple literal, putting braces around `a<b` or `c>(d)` will make it parse correctly.

- the design of comune's reference semantics was partially based on [the difficulties of dealing with unsafe pointers in Rust](https://faultlore.com/blah/fix-rust-pointers/#offsets-and-places-are-a-mess); as it turns out, having [no core-language way to create a pointer without using references](https://doc.rust-lang.org/stable/std/ptr/macro.addr_of.html) Kind Of Sucks!

- "comune" is an italian word roughly translating to "township", but the choice of name mostly stems from "communing" with C++, the desire to foster a good community (if this thing goes anywhere), and the inherent Funny Value of being able to call myself a *comunist* \[sic]. side note: as far as i'm concerned, the name is stylized in all-lowercase.

## compiler progress

so that's all well and good, but how much of this is actually *implemented*, and not just fancy talk from some smartass on the internet? 

well, a solid amount! in fact, it might be easier to list what's *not* yet ready, off the top of my head:

- `impl` blocks currently don't propagate across modules, severely limiting their usability. (this is what i'm working on at time of writing)
- although the basic dataflow analysis framework is functional, borrowchecking is still limited to simply ensuring variable initialization before use, with no support for shared-xor-mutable checks just yet.
- pattern matching is half-implemented, with no exhaustiveness checks and brittle cIR generation. also nothing beyond basic bindings is implemented like At All
- sum types have decent support, but enums are still pretty much non-functional 
- dynamic drop is partially implemented, but doesn't yet take scope ends, `break` or `continue` into account. this is mostly a matter of
- `for` is just your basic C-style `for` loop right now, and i want to replace it with a proper iterator system at some point.
- constant evaluation only works in trivial cases right now, and i've been meaning to rewrite it with a proper IR interpreter.
- the basic monomorphization system works, but the cIR phase doesn't yet (have the ability to) redo overload resolution for function instantiations, which will inevitably lead to Trouble (the way generics interact with function overloading is pretty vague in general)
- although function pointers are implemented, actually taking the address of a function doesn't currently work
- name resolution is kind of a mess but it works
- still really need a proper reborrowing system for `T mut&`
- c++ interop? hahahahahahahahahahahahahahaha i mean you can import a cpp file and call an extremely simple comune function from c++ (NOT the other way around) using some extremely hacked together bullshit! if you want!
- we still need a whole-ass trait solver oh my God
- probably like a billion other small things i'm forgetting

i hope this paints a decent picture of the state of the compiler; a LOT of things work, and a lot of things still don't, and while some aspects of the language are still vaguely-defined, there's also a lot that you can experiment with right now. we're not quite there yet, but the language is closer to an 0.1 release than i honestly ever assumed it would be, and if the language as described in this blog post intrigues or excites you, we'd love for you to [come help out](https://github.com/comune-lang/comune). 

despite the semi-hobbyist way i described the language at the start of this blog post, the reason i've worked on comune for so long is because i genuinely believe it's a promising project, and i hope you agree. thanks for reading!