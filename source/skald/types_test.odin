package skald

import "core:testing"

@(test)
test_find_collections :: proc(t: ^testing.T) {
	Box :: struct {
		pos: [2]f32,
	}
	Coin :: struct {
		value: int,
	}
	State :: struct {
		frames: int,
		boxes: Collection(Box),
		coins: Collection(Coin),
		handle: Handle(Box),
	}

	found := find_collections(type_info_of(State))
	defer delete(found)

	testing.expect_value(t, len(found), 2)
	if len(found) != 2 {
		return
	}

	testing.expect_value(t, found[0].name, "boxes")
	testing.expect_value(t, found[0].offset, offset_of(State, boxes))
	testing.expect(t, found[0].item.id == Box)

	testing.expect_value(t, found[1].name, "coins")
	testing.expect(t, found[1].item.id == Coin)

	testing.expect(t, collection_item(type_info_of(int)) == nil)
	testing.expect(t, collection_item(type_info_of(Handle(Box))) == nil)
}