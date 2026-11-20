package main

import "base:runtime"
import "core:testing"

import "skald:platform"
import "skald:ui"

@(private="file")
measure :: proc(font: platform.Font, text: string, size: f32) -> [2]f32 {
	return {f32(len(text)) * size / 2, size}
}

@(private="file")
frame :: proc(input: ui.Input, data: rawptr, ti: ^runtime.Type_Info) -> bool {
	ui.begin(&ctx, input)
	defer ui.end(&ctx)
	return edit_value("v", data, ti)
}

@(test)
test_edit_widgets :: proc(t: ^testing.T) {
	ui.init(&ctx, measure, 0, 1)
	defer ui.destroy(&ctx)

	load_level(&level, "", {})
	defer unload_level(&level)

	at := [2]f32{ctx.theme.padding + 2, ctx.theme.padding + 2}

	Kind :: enum u8 {
		Slime = 2,
		Bat = 5,
		Bird = 9,
	}
	k := Kind.Bat
	frame({mouse = at}, &k, type_info_of(Kind))
	frame({mouse = at, down = {.Left}}, &k, type_info_of(Kind))
	testing.expect(t, frame({mouse = at}, &k, type_info_of(Kind)))
	testing.expect_value(t, k, Kind.Bird)

	s := "ab"
	frame({mouse = at}, &s, type_info_of(string))
	frame({mouse = at, down = {.Left}}, &s, type_info_of(string))
	frame({mouse = at}, &s, type_info_of(string))
	testing.expect(t, frame({mouse = at, text = "c"}, &s, type_info_of(string)))
	testing.expect(t, frame({mouse = at, keys = {.Backspace}}, &s, type_info_of(string)))
	testing.expect_value(t, s, "ab")
	testing.expect(t, frame({mouse = at, text = "z"}, &s, type_info_of(string)))
	testing.expect_value(t, s, "abz")

	tag := Inspect_Tag{ranged = true, lo = 0, hi = 10}
	hp := 5
	ui.begin(&ctx, {mouse = at})
	edit_value("hp", &hp, type_info_of(int), tag)
	ui.end(&ctx)
	ui.begin(&ctx, {mouse = at, down = {.Left}})
	edit_value("hp", &hp, type_info_of(int), tag)
	ui.end(&ctx)
	ui.begin(&ctx, {mouse = at + {500, 0}, down = {.Left}})
	edit_value("hp", &hp, type_info_of(int), tag)
	ui.end(&ctx)
	testing.expect_value(t, hp, 10)

	Flag :: enum {
		Fire = 1,
		Ice = 3,
	}
	flags := bit_set[Flag]{.Ice}
	frame({mouse = at}, &flags, type_info_of(type_of(flags))) // releases the hp drag
	frame({mouse = at}, &flags, type_info_of(type_of(flags)))
	frame({mouse = at, down = {.Left}}, &flags, type_info_of(type_of(flags)))
	testing.expect(t, frame({mouse = at}, &flags, type_info_of(type_of(flags))))
	testing.expect_value(t, flags, bit_set[Flag]{.Fire, .Ice})

	Circle :: struct {
		radius: f32,
	}
	shape: union {
		Circle,
		int,
	}
	frame({mouse = at}, &shape, type_info_of(type_of(shape)))
	frame({mouse = at, down = {.Left}}, &shape, type_info_of(type_of(shape)))
	testing.expect(t, frame({mouse = at}, &shape, type_info_of(type_of(shape))))
	testing.expect_value(t, shape.(Circle), Circle{})
}

@(test)
test_parse_inspect_tag :: proc(t: ^testing.T) {
	testing.expect_value(t, parse_inspect_tag("range=0,100"), Inspect_Tag{ranged = true, lo = 0, hi = 100})
	testing.expect_value(t, parse_inspect_tag("hide"), Inspect_Tag{hide = true})
	testing.expect_value(t, parse_inspect_tag("color range=-1,1"), Inspect_Tag{color = true, ranged = true, lo = -1, hi = 1})
	testing.expect_value(t, parse_inspect_tag("range=5,1"), Inspect_Tag{})
	testing.expect_value(t, parse_inspect_tag(""), Inspect_Tag{})
}