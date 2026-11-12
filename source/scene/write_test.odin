package scene

import "core:strings"
import "core:testing"

@(test)
test_write_struct :: proc(t: ^testing.T) {
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

	e := Enemy{hp = 3, speed = 0.1, alive = true, pos = {412, -233.5}, kind = .Bat, name = "bob"}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)

	write_struct(&sb, e)

	expected := "hp = 3\nspeed = 0.1\nalive = true\npos = 412 -233.5\nkind = Bat\nname = \"bob\"\n"
	testing.expect_value(t, strings.to_string(sb), expected)
}

@(test)
test_round_trip :: proc(t: ^testing.T) {
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

	e := Enemy{hp = -3, speed = 0.1, alive = true, pos = {412, -233.5}, kind = .Bat, name = "bob \"the\" slime"}

	first := strings.builder_make()
	defer strings.builder_destroy(&first)
	write_struct(&first, e)

	back: Enemy
	ok := read_struct(strings.to_string(first), &back, Enemy)
	defer delete(back.name)

	testing.expect(t, ok)
	testing.expect_value(t, back, e)

	second := strings.builder_make()
	defer strings.builder_destroy(&second)
	write_struct(&second, back)

	testing.expect_value(t, strings.to_string(second), strings.to_string(first))
}

@(test)
test_skip_defaults :: proc(t: ^testing.T) {
	Enemy :: struct {
		hp: int,
		speed: f32,
		pos: [2]f32,
		name: string,
	}

	DEFAULT :: Enemy{hp = 3, speed = 1, name = "slime"}

	e := DEFAULT
	e.pos = {10, 20}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)

	write_struct(&sb, e, DEFAULT)
	testing.expect_value(t, strings.to_string(sb), "pos = 10 20\n")

	back := DEFAULT
	testing.expect(t, read_struct(strings.to_string(sb), &back, Enemy))
	testing.expect_value(t, back, e)
}