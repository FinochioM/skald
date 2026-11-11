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

@(test)
test_remove_and_reuse :: proc(t: ^testing.T) {
	Thing :: struct {
		id: int,
	}

	N :: 10_000

	c := make_collection(Thing)
	defer destroy_collection(&c)

	handles := make([]Handle(Thing), N)
	defer delete(handles)

	for i in 0 ..< N {
		handles[i] = add(&c, Thing{id = i})
	}

	for i := 0; i < N; i += 2 {
		testing.expect(t, remove(&c, handles[i]))
	}
	testing.expect_value(t, count(&c), N / 2)

	testing.expect(t, !remove(&c, handles[0]))

	for _ in 0 ..< N / 2 {
		add(&c, Thing{id = -1})
	}
	testing.expect_value(t, len(c.slots), N)
	testing.expect_value(t, count(&c), N)

	for h, i in handles {
		thing := get(&c, h)
		if i % 2 == 0 {
			testing.expectf(t, thing == nil, "stale handle %d still resolves", i)
		} else {
			testing.expect_value(t, thing.id, i)
		}
	}
}

@(test)
test_iterate_skips_removed :: proc(t: ^testing.T) {
	Thing :: struct {
		id: int,
	}

	c := make_collection(Thing)
	defer destroy_collection(&c)

	a := add(&c, Thing{id = 1})
	b := add(&c, Thing{id = 2})
	add(&c, Thing{id = 3})
	remove(&c, b)

	sum := 0
	seen := 0
	it := make_iterator(&c)
	for thing, h in iterate(&it) {
		sum += thing.id
		seen += 1

		testing.expect(t, get(&c, h) == thing)
	}

	testing.expect_value(t, seen, 2)
	testing.expect_value(t, sum, 4)
	testing.expect(t, get(&c, a) != nil)
}
