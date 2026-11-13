package scene

import "core:strings"
import "core:testing"

@(test)
test_was_tag :: proc(t: ^testing.T) {
	Old :: struct {pos: [2]f32, hp: int}
	New :: struct {position: [2]f32 `was:"pos"`, hp: int}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	write_struct(&sb, Old{pos = {1, 2}, hp = 3})

	text: New
	testing.expect(t, read_struct(strings.to_string(sb), &text, New))
	testing.expect_value(t, text.position, [2]f32{1, 2})
	testing.expect_value(t, text.hp, 3)

	data: [dynamic]byte
	defer delete(data)
	write_binary_struct(&data, Old{pos = {4, 5}, hp = 6})

	binary: New
	testing.expect(t, read_binary_struct(data[:], &binary, New))
	testing.expect_value(t, binary.position, [2]f32{4, 5})
	testing.expect_value(t, binary.hp, 6)
}