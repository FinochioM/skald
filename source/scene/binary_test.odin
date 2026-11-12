package scene

import "core:testing"

@(test)
test_binary_round_trip :: proc(t: ^testing.T) {
	Kind :: enum {
		Slime,
		Bat,
	}

	Enemy :: struct {
		hp: int,
		speed: f32,
		alive: bool,
		pos: [2]f32,
		kind: Kind,
		name: string,
	}

	e := Enemy{hp = -3, speed = 0.1, alive = true, pos = {412, -233.5}, kind = .Bat, name = "bob"}

	buf := make([dynamic]byte)
	defer delete(buf)
	write_binary_struct(&buf, e)

	back: Enemy
	testing.expect(t, read_binary_struct(buf[:], &back, Enemy))
	defer delete(back.name)

	testing.expect_value(t, back, e)
}

@(test)
test_binary_survives_changes :: proc(t: ^testing.T) {
	Old :: struct {
		hp: int,
		gold: int,
		name: string,
	}

	New :: struct {
		name: string,
		mana: int,
		hp: i32,
	}

	buf := make([dynamic]byte)
	defer delete(buf)
	write_binary_struct(&buf, Old{hp = 7, gold = 50, name = "zed"})

	back := New{mana = 10, hp = 1}
	testing.expect(t, read_binary_struct(buf[:], &back, New))
	defer delete(back.name)

	testing.expect_value(t, back.name, "zed")
	testing.expect_value(t, back.mana, 10)
	testing.expect_value(t, back.hp, 1)
}