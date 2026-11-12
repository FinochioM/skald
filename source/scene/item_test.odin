package scene

import "core:strings"
import "core:testing"

@(test)
test_items :: proc(t: ^testing.T) {
	Box :: struct {
		pos: [2]f32,
		vel: [2]f32,
	}

	a := Box{pos = {1, 2}, vel = {3, 4}}
	b := Box{pos = {5, 6}}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)

	write_item(&sb, 0x7f3a91c2e4b05d18, a, Box{})
	write_item(&sb, 2, b, Box{})
	text := strings.to_string(sb)

	expected := "Box 7f3a91c2e4b05d18\n  pos = 1 2\n  vel = 3 4\nBox 0000000000000002\n  pos = 5 6\n"
	testing.expect_value(t, text, expected)

	rest := text
	got: [2]Box
	ids: [2]u64
	n := 0
	for type_name, id, body in next_item(&rest) {
		testing.expect_value(t, type_name, "Box")
		testing.expect(t, read_struct(body, &got[n], Box))
		ids[n] = id
		n += 1
	}

	testing.expect_value(t, n, 2)
	testing.expect_value(t, ids, [2]u64{0x7f3a91c2e4b05d18, 2})
	testing.expect_value(t, got[0], a)
	testing.expect_value(t, got[1], b)
}