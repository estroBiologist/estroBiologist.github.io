---
title: "covering comune: lifetimes and bind generics"
layout: post
author: ash

---
let's talk about lifetimes, mutability, and generics in comune.

For some time now, I've been looking for a way to integrate a couple features into comune in a way that *feels nice*.

{% codelog C++ %}

~~~ cpp
import module_test;
import vector;
//import cpp_test;

module submodule_test;

using module_test::fib;
using core::traits::Drop;
using vector::Vector;
using ascii = u8;
using core::mem::{malloc, free, bit_cast, size_of};

@no_mangle
int printf(ascii* fmt, ...);

struct Test {
	int a;
	int b;
}

enum EnumTest {
	VariantA,
	VariantB,
}

impl Test {
	int sum(Test& self) {
		printf(c"This is a method call!\n");
		self.a + self.b
	}
	
	// the `self` parameter's type can be omitted
	int product(&self) {
		self.a * self.b
	}
}

impl Drop for Test {
	void drop(mut& self) {
		printf(c"This is Test's destructor!\n");
	}
}

impl submodule_test::SubmoduleTrait for Test {
	void foo() {
		printf(c"This is a trait in a submodule!\n");
	}
}

trait Hello {
	void hello(Self& self);
}

impl Hello for Test {
	void hello(Test& self) {
		printf(c"Hello Test!\n");
	}
}


void impl_test() {
	Test test = Test { a: 413, b: 612, };
	test.hello();
	printf(c"The sum of a and b is %i!\n", test.sum());
}

void ref_test(i32 mut& test) {
	test++;
}

void fn_pointer_test(void(int) callback) {
	callback(12);
}

void fn_pointer_callback(int number) {
	printf(c"this is a callback! %i\n", number);
}


void overload_test(i32 a) {
	printf(c"i32 overload called!\n");
}

void overload_test(i64 a) {
	printf(c"i64 overload called!\n");
}

Vector<i32> generic_ret() {
	return Vector<i32> {
		data: malloc(4) as i32 mut*,
		len: 1,
		capacity: 1,
	};
}

using TestSumType = (i32 | f32);

TestSumType sum_type_test(i32& value) {
	return value;
}

// In lieu of properly working static functions
Vector<T> vec<type T>() {
	Vector<T> {
		data: malloc(0) as T mut*,
		capacity: 0,
		len: 0,
	}
}

i32& ref_return(i32 mut& in) {
	in
}

void slice_test(i32[] &test) { }

int main() {
	submodule_test::bar();

	Vector<float> a = vec<float>();
	vector::vector_test(a);

	int i;

	if true {
		i = 12;
	} else {
		i = 12;
	}

	int mut i = i;

	i = 12;

	{
		int explicit_scope_test = 23;
	}

	// `else if` syntax test
	
	if i == 12 {
		int scope_test = 15;
		int scope_test_2 = 15;
		printf(c"i is 12!\n");
	} else if i == 13 {
		printf(c"i is 13!\n");
	} else {
		printf(c"i is something else!\n");
	}

	void(int) function;
	//function(12);
	//fn_pointer_test(fn_pointer_callback);

	TestSumType mut who_knows = sum_type_test(322);

	match who_knows {
		int int_result => {
			printf(c"It's an int! %i\n", int_result)
		}

		float float_result => {
			printf(c"It's a float! %f\n", float_result)
		}
	}
	
	int mut loop_count = 0;
	
	while true {		
		loop_count += 1;

		if loop_count > 100 {
			int loop_init_test = 12;
			break;
		}
	}

	printf(c"Loop count after loop: %i\n", loop_count);
	
	impl_test();

	overload_test(12i32);

	int int_ref_test = 12;
	ref_test(int_ref_test);
	printf(c"int_ref_test: %i\n", int_ref_test);

	printf(c"Temporary->lvalue promotion: %i\n", Test { a: 23, b: 35 }.sum());

	printf(c"bit_cast<f32, u32>: %i\n", bit_cast<f32, u32>(10.0f32));
	return 0;
}

~~~

{% endcodelog %}

cool stuff, right?