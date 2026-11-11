package skald

import "core:testing"

@(test)
test_add_get :: proc(t: ^testing.T) {
	Thing :: struct {
		hp: int,
	}

	c := make_collection(Thing)
	defer destroy_collection(&c)

	a := add(&c, Thing{hp = 3})
	b := add(&c, Thing{hp = 7})

	testing.expect_value(t,get(&c, a).hp, 3)
	testing.expect_value(t,get(&c, b).hp, 7)

	testing.expect(t, get(&c, Handle(Thing){}) == nil)
}
