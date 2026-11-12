package skald

import "core:strings"
import "core:testing"

@(test)
test_save_load_save :: proc(t: ^testing.T) {
	Box :: struct {
		pos: [2]f32,
		vel: [2]f32,
	}

	a := make_collection(Box)
	defer destroy_collection(&a)

	add(&a, Box{pos = {1, 2}, vel = {3, 4}})
	h := add(&a, Box{pos = {5, 6}})
	add(&a, Box{vel = {-7, 8}})
	remove(&a, h)

	first := strings.builder_make()
	defer strings.builder_destroy(&first)
	save_collection(&first, &a, Box{})

	b := make_collection(Box)
	defer destroy_collection(&b)
	testing.expect(t, load_collection(&b, strings.to_string(first), Box{}))
	testing.expect_value(t, count(&b), 2)

	second := strings.builder_make()
	defer strings.builder_destroy(&second)
	save_collection(&second, &b, Box{})

	testing.expect_value(t, strings.to_string(second), strings.to_string(first))
}

@(test)
test_one_field_one_line :: proc(t: ^testing.T) {
	Box :: struct {
		pos: [2]f32,
		vel: [2]f32,
	}

	c := make_collection(Box)
	defer destroy_collection(&c)

	handles: [50]Handle(Box)
	for &h, i in handles {
		h = add(&c, Box{pos = {f32(i), f32(i) * 2}, vel = {1, -1}})
	}

	before := strings.builder_make()
	defer strings.builder_destroy(&before)
	save_collection(&before, &c, Box{})

	get(&c, handles[17]).vel.x = 99

	after := strings.builder_make()
	defer strings.builder_destroy(&after)
	save_collection(&after, &c, Box{})

	a := strings.split_lines(strings.to_string(before), context.temp_allocator)
	b := strings.split_lines(strings.to_string(after), context.temp_allocator)
	testing.expect_value(t, len(b), len(a))

	changed := 0
	for i in 0 ..< min(len(a), len(b)) {
		if a[i] != b[i] {
			changed += 1
		}
	}
	testing.expect_value(t, changed, 1)
}