package main

import "core:testing"

@(test)
test_undo_redo :: proc(t: ^testing.T) {
	Box :: struct {
		x: f32,
	}

	lvl: Editor_Level
	load_level(&lvl, "", {{name = "boxes", item = type_info_of(Box)}})
	defer unload_level(&lvl)

	box := Box{1}
	append(&lvl.collections[0].items, Item{7, (cast([^]byte)&box)[:size_of(Box)]})

	for x in ([]f32{2, 3, 4}) {
		before := box
		box.x = x
		touch(&lvl, 7, (cast([^]byte)&before)[:size_of(Box)])
	}
	settle(&lvl)

	before := box
	box.x = 10
	touch(&lvl, 7, (cast([^]byte)&before)[:size_of(Box)])
	settle(&lvl)

	testing.expect_value(t, len(lvl.history.edits), 2)

	testing.expect(t, undo(&lvl))
	testing.expect_value(t, box.x, 4)
	testing.expect(t, undo(&lvl))
	testing.expect_value(t, box.x, 1)
	testing.expect(t, !undo(&lvl))

	testing.expect(t, redo(&lvl))
	testing.expect_value(t, box.x, 4)

	before = box
	box.x = 5
	touch(&lvl, 7, (cast([^]byte)&before)[:size_of(Box)])
	settle(&lvl)
	testing.expect(t, !redo(&lvl))
	testing.expect_value(t, len(lvl.history.edits), 2)
}