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
test_edit_enum_and_string :: proc(t: ^testing.T) {
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
}