package reload

import "core:testing"

@(test)
test_same_layout :: proc(t: ^testing.T) {
	A :: struct {x: int, y: f32}
	B :: struct {x: int, y: f32}
	C :: struct {y: f32, x: int}

	testing.expect(t, layout_hash(type_info_of(A)) == layout_hash(type_info_of(B)))
	testing.expect(t, layout_hash(type_info_of(A)) != layout_hash(type_info_of(C)))
}

@(test)
test_migrate :: proc(t: ^testing.T) {
	Old_Item :: struct {pos: [2]f32, hp: int}
	New_Item :: struct {hp: int, speed: f32, pos: [2]f32}

	Old :: struct {
		name: string,
		score: int,
		items: [dynamic]Old_Item,
		gone: bool,
	}
	New :: struct {
		lives: int,
		points: int `was:"score"`,
		items: [dynamic]New_Item,
		name: string,
	}

	old := Old{name = "boxes", score = 42}
	append(&old.items, Old_Item{{1, 2}, 10}, Old_Item{{3, 4}, 20})

	new: New
	migrate(&new, type_info_of(New), &old, type_info_of(Old))
	defer delete(new.items)

	testing.expect_value(t, new.name, "boxes")
	testing.expect_value(t, new.points, 42)
	testing.expect_value(t, new.lives, 0)
	testing.expect_value(t, len(new.items), 2)
	testing.expect_value(t, new.items[1].pos, [2]f32{3, 4})
	testing.expect_value(t, new.items[1].hp, 20)
	testing.expect_value(t, new.items[1].speed, 0)
}