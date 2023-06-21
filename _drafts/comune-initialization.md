---
title: "clear comune-ication: initialization and references"
layout: post
author: ash
excerpt: on references, initialization and exception safety in comune.
---

howdy hey! the response to the last blog post has been great - thanks for all the kind words and feedback :)

there's still a *lot* about comune i wasn't able to cover in detail, so i want to try and write some smaller blog posts covering specific features, design choices and implementation stories. the first thing i'd like to cover is the language's reference and initialization systems, with a potential tangent about exception safety thrown in too.

for the basics of comune's references, the [the previous post]({% post_url 2023-06-06-introducing-comune %}),

## bindings

## dropping values

like in Rust, using `_` as a variable name makes it *anonymous*, preventing you from referencing it later on. *unlike* Rust, this anonymous variable lives until the end of the scope, preventing footguns such as `let _ = mutex.lock();`. if you want to suppress an "unused result" warning (not that comune has those yet), you can use a `drop` expression.

## initialization

different languages handle variable initialization differently. the easiest solution is just to set everything to a "null", "zero" or "empty" value[^1] and let the user choose whether to assign something else to it. this *works*, but it can lead to problems - not every type needs the concept of "nothin' here, bud", and having to deal with the possibility of any value being `null` is generally considered *slightly problematic* - so other languages may choose to take a different approach.

so let's talk about C++'s initialization story.

<div style="transform: scaleX(2);">aaaaaaaaaaaAAAAAAAAAAAAAAAAAAAAAAAAA</div>

so let's talk about comune's initialization story.

comune uses [Definite Initialization](https://en.wikipedia.org/wiki/Definite_assignment_analysis) to ensure that any variable you try to use has *Definitely* been *Initialized*. this is, in my opinion, the cleanest solution, and it's the one used by languages like Swift and Rust, but it takes more work on the compiler vendors' part (that's me, in this case - i'm the control-flow critic, i analyze it so you don't have to.)

for more information on Definite Initialization, check out this [Faultlore article](https://faultlore.com/blah/deinitialize-me-maybe/#background-concept-3-definite-initialization-analysis), but suffice it to say, it was a pain in the ass to implement - i had to get a PDF of an honest-to-god college textbook and bash my head against the inscrutable jargon to figure out how to write a dataflow analysis framework[^2].

i mean LOOK at this

![a page from a math textbook full of inscrutable symbols. i'm not even gonna try to transcribe this.](/assets/images/blog/stop_doing_math.png)

<div style="font-family: sans-serif; font-weight: 600; font-size: 16px;">They have played us for absolute fools</div>

point being: comune will statically ensure you've assigned a value to a variable before using it. great, awesome, problem solved.

so what are the ways in which we can initialize things? well, for built-in types you can always just use a *literal*. you know, things like `0`, `[]` and `"Hello world!"` - integer, array and string literals, respectively.

for user-defined types, you can also use a type of literal - as long as you have access to all the fields.

{% codelog Code %}
```cpp
struct MyType {
	public int a;
	public int b;
}

int main() {
	// Pretend type inference is actually implemented
	auto my_cool_var = new MyType { a: 413, b: 612 };
}
```
{% endcodelog %}

but what if you don't? well, then you can use *constructors*!

{% codelog Code %}
```cpp
struct MyType {
	int a;
	int b;

	// A user-defined constructor!
	new(new& self, int a, int b) {
		self.a = a;
		self.b = b;
	}
}

int main() {
	auto my_cool_var = new MyType(1025, 322);
}
```
{% endcodelog %}

but hey, what's that `new& self` parameter in the constructor? we haven't created a `MyType` yet, that's what the constructor is *for*. so what are we referencing? oh god i feel a segue coming on

## new& - a weirdly elegant hack

SO YOU WANT TO INITIALIZE DATA AT A DISTANCE.

this is a complaint often leveraged against Rust's constructor story - the only way to directly create an object in Rust is to use a *literal*, and move the result into your variable. while super simple and elegant, it doesn't offer the ability to perform what C++ users would call "placement `new`", which is directly accessing the uninitialized data and overwriting it. 

in most cases, the difference is fairly negligible (especially with optimizations enabled), but the Rust method does involve an unnecessary move, as well as always creating the whole object on the stack and moving it to its final location after. sometimes, you want to know exactly where an object's being constructed! in comune, that's where `new&` comes in.

`new&` is a special kind of reference that can only be used as a function parameter. unlike every other kind of reference, `new&` lets you handle logically uninitialized data, letting you initialize it in-place.

let's take another look at that constructor:

{% codelog code %}
```cpp
new(new& self, int a, int b) {
	self.a = a;
	self.b = b;
}
```
{% endcodelog %}

if we comment out one or both of the assignments, we get a compiler error:

`error: new& binding must be initialized in all control flow paths`

this is how the compiler ensures `new&` is safe - you can't read from it until you've initialized it, and once you have, it "turns into" a `mut&`, letting you call methods on it and everything. you also *have to* make sure it's initialized by the end of the function. you can even move out of it, as long as it's all there when you `return`!

but hang on. is that also true for `mut&`, then?


{% codelog code %}
```cpp
void do_the_ol_switcheroo(MyType mut& test) {
	MyType impostor = test;
}
```
{% endcodelog %}

`error: moved-from mut& binding must be re-initialized in all control flow paths`

oh right one sec

{% codelog code %}
```cpp
void do_the_ol_switcheroo(MyType mut& test) {
	MyType impostor = test;
	test = new MyType();
}
```
{% endcodelog %}

`(all good)`

neat! Rust wouldn't let you do this[^3] - moving out of a mutable reference isn't considered kosher by its type system. but we get a little silly here in comune land. go on, move out of that mutable reference. no one'll notice, as long as you put something there in its place.

so yeah, `new&` is essentially just a special case of `mut&`; the "initializing mutable reference", or just "initializing reference", i guess.

## the aforementioned tangent about exception safety

comune's memory safety features are obviously hugely inspired by Rust - taking into account both its strengths and weaknesses. 

in my opinion, one such weakness is *exception safety* - basically, the fact that even seemingly-innocuous operations like "incrementing an integer" could *panic* (throw an exception) and exit the function early, leaving whatever operation you were doing incomplete.

in and of itself, this wouldn't be much of a problem - a panic is meant to be a Really Bad Error, and it's generally not a good idea to continue from one[^4]. [but it is possible](https://doc.rust-lang.org/std/panic/fn.catch_unwind.html), and that leads to Problems.

### Oh God, Basically Every Operation Ever Could Diverge

so yeah, panics in Rust are not just "okay, we fucked up, call the whole thing off" - they involve unwinding the stack and calling the destructors for everything in scope, all the way up to and out of `main()`, and *then* exiting the program. this has some considerable advantages - it's nice to clean up after yourself! unfortunately, this behaviour also makes Literally Everything More Complicated.

as the [Nomicon](https://doc.rust-lang.org/nomicon/exception-safety.html) will tell you, `unsafe` code has to be be particularly aware of this fact, because forgetting about it at any point could easily lead to your code's invariants being smashed with a sledgehammer and flushed down the toilet. it is an absolute pain in the ass - highly recommend checking out that link if you're a fan of migraines.

considering comune lets you do things like *initialize data through a reference*, the ergonomic impact of this would be Bad - nevermind how much of a pain it would be to implement proper unwind paths on my end! i mean, have you SEEN what kind of IR the compiler emits??? it's unoptimized enough as-is[^5]!

so this points to an obvious alternative: Just Don't Do That! If It Sucks Hit Da Bricks! just `abort()` the damn program on panic and depend on the OS to clean everything up. Rust itself literally has an option to do [this exact thing](https://doc.rust-lang.org/book/ch09-01-unrecoverable-errors-with-panic.html#unwinding-the-stack-or-aborting-in-response-to-a-panic), so it's not like it's unprecedented - it just leads to your programs crashing and burning in a somewhat less elegant manner.

abort-on-panic *does* mean you can't catch these sorts of errors at the thread boundary by default - you'll have to propagate any errors manually, using i.e. `try_x()` style APIs that don't panic on error[^6]. i recogize that this approach has shortcomings, but i think it's the best option for comune. 

for use cases where this system is seriously problematic (as well as C++ interop purposes), i'm open to the possibility of adding opt-in unwinding in the future. for now, rejoice in the knowledge that you'll be able to lock a damn `Mutex` without having to `unwrap()` all the time.

## footnotes
[^1]: though be warned - those can absolutely be different things.
[^2]: let it never be said i can't push through boring work.
[^3]: at least, [not directly](https://doc.rust-lang.org/std/mem/fn.swap.html)
[^4]: yes, i know, panics are also supposed to be caught at thread boundaries, but my god have you SEEN the horrors that adds to the standard concurrency types 
[^5]: mostly a joke but *god* i need to optimize some of this stuff. tried writing a cleanup pass that removes useless blocks, but they're stored in an array so all the indices got messed up and i just couldn't be bothered
[^6]: because, ICYMI, comune 1000% embraces sum types as a first-class language feature, including `Result<T, E>`