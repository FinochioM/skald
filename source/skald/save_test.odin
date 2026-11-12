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