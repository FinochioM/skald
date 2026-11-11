package skald

import "core:testing"

@(test)
test_level_frees_everything :: proc(t: ^testing.T) {
	Thing :: struct {
		id: int,
	}

	lvl: Level
	level_init(&lvl)

	things := make_collection(Thing, lvl.allocator)
	for i in 0 ..< 10_000 {
		add(&things, Thing{id = i})
	}
	testing.expect_value(t, count(&things), 10_000)

	level_destroy(&lvl)
}
