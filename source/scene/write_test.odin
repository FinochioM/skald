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