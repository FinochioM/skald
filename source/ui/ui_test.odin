package ui

import "core:testing"

import "skald:platform"

@(private="file")
PADDING :: DEFAULT_THEME.padding
@(private="file")
SPACING :: DEFAULT_THEME.spacing
@(private="file")
SLIDER_WIDTH :: DEFAULT_THEME.slider_width

@(private="file")
fake_measure :: proc(font: platform.Font, text: string, size: f32) -> [2]f32 {
	return {f32(len(text)) * size * 0.5, size}
}

@(private="file")
frame :: proc(ctx: ^Context, mouse: [2]f32, down: platform.Mouse_Buttons) -> (clicked: bool) {
	begin(ctx, {mouse = mouse, down = down})
	clicked = button(ctx, "ok")
	end(ctx)
	return
}

@(test)
test_button_click :: proc(t: ^testing.T) {
	ctx: Context
	init(&ctx, fake_measure, 0, 1)
	defer destroy(&ctx)

	over := [2]f32{PADDING + 2, PADDING + 2}

	testing.expect(t, !frame(&ctx, over, {}))
	testing.expect(t, !frame(&ctx, over, {.Left}))
	testing.expect(t, frame(&ctx, over, {}))
	testing.expect(t, !frame(&ctx, {500, 500}, {}))

	frame(&ctx, over, {})
	frame(&ctx, over, {.Left})
	testing.expect(t, !frame(&ctx, {500, 500}, {}))
}

@(test)
test_ids :: proc(t: ^testing.T) {
	ctx: Context
	init(&ctx, fake_measure, 0, 1)
	defer destroy(&ctx)

	a := get_id(&ctx, "ok")
	push_id(&ctx, "panel")
	b := get_id(&ctx, "ok")
	pop_id(&ctx)

	testing.expect(t, a != b)
	testing.expect(t, a == get_id(&ctx, "ok"))
}

@(test)
test_row_layout :: proc(t: ^testing.T) {
	ctx: Context
	init(&ctx, fake_measure, 0, 1)
	defer destroy(&ctx)

	begin(&ctx, {})
	a, b: Rect
	{
		row(&ctx)
		a = next_rect(&ctx, {10, 20})
		b = next_rect(&ctx, {30, 5})
	}
	c := next_rect(&ctx, {1, 1})
	end(&ctx)

	testing.expect_value(t, a.pos, [2]f32{PADDING, PADDING})
	testing.expect_value(t, b.pos, [2]f32{PADDING + 10 + SPACING, PADDING})
	testing.expect_value(t, c.pos, [2]f32{PADDING, PADDING + 20 + SPACING})
}

@(test)
test_checkbox_and_slider :: proc(t: ^testing.T) {
	ctx: Context
	init(&ctx, fake_measure, 0, 1)
	defer destroy(&ctx)

	on: bool
	v: f32
	box := [2]f32{PADDING + 2, PADDING + 2}
	slider_y := f32(PADDING + 16 + SPACING + 4)

	step :: proc(ctx: ^Context, mouse: [2]f32, down: platform.Mouse_Buttons, on: ^bool, v: ^f32) {
		begin(ctx, {mouse = mouse, down = down})
		checkbox(ctx, "on", on)
		slider(ctx, "v", v, 0, 10)
		end(ctx)
		free_all(context.temp_allocator)
	}

	step(&ctx, box, {}, &on, &v)
	step(&ctx, box, {.Left}, &on, &v)
	step(&ctx, box, {}, &on, &v)
	testing.expect(t, on)

	step(&ctx, {PADDING + 1, slider_y}, {}, &on, &v)
	step(&ctx, {PADDING + 1, slider_y}, {.Left}, &on, &v)
	step(&ctx, {PADDING + SLIDER_WIDTH / 2, slider_y}, {.Left}, &on, &v)
	testing.expect_value(t, v, 5)
	step(&ctx, {9999, 9999}, {.Left}, &on, &v)
	testing.expect_value(t, v, 10)
}

@(test)
test_panel_drag :: proc(t: ^testing.T) {
	ctx: Context
	init(&ctx, fake_measure, 0, 1)
	defer destroy(&ctx)

	r := Rect{{100, 100}, {200, 150}}
	step :: proc(ctx: ^Context, mouse: [2]f32, down: platform.Mouse_Buttons, r: ^Rect) {
		begin(ctx, {mouse = mouse, down = down})
		panel(ctx, "p", r)
		end(ctx)
	}

	step(&ctx, {110, 105}, {}, &r)
	step(&ctx, {110, 105}, {}, &r)
	step(&ctx, {110, 105}, {.Left}, &r)
	step(&ctx, {160, 155}, {.Left}, &r)
	step(&ctx, {160, 155}, {}, &r)
	testing.expect_value(t, r.pos, [2]f32{150, 150})
}

@(test)
test_panel_clips_input :: proc(t: ^testing.T) {
	ctx: Context
	init(&ctx, fake_measure, 0, 1)
	defer destroy(&ctx)

	r := Rect{{100, 100}, {200, 40}}
	step :: proc(ctx: ^Context, mouse: [2]f32, down: platform.Mouse_Buttons, r: ^Rect) -> (clicked: bool) {
		begin(ctx, {mouse = mouse, down = down})
		panel(ctx, "p", r)
		clicked = button(ctx, "ok")
		end(ctx)
		return
	}

	inside_button := [2]f32{112, 150}
	step(&ctx, inside_button, {}, &r)
	step(&ctx, inside_button, {.Left}, &r)
	testing.expect(t, !step(&ctx, inside_button, {}, &r))
}

@(test)
test_panel_front :: proc(t: ^testing.T) {
	ctx: Context
	init(&ctx, fake_measure, 0, 1)
	defer destroy(&ctx)

	a := Rect{{0, 0}, {200, 200}}
	b := Rect{{20, 20}, {200, 200}}
	step :: proc(ctx: ^Context, mouse: [2]f32, down: platform.Mouse_Buttons, a, b: ^Rect) -> (clicked: bool) {
		begin(ctx, {mouse = mouse, down = down})
		begin_panel(ctx, "a", a)
		clicked = button(ctx, "ok")
		end_panel(ctx)
		begin_panel(ctx, "b", b)
		end_panel(ctx)
		end(ctx)
		return
	}

	on_button := [2]f32{25, 50}
	click :: proc(ctx: ^Context, mouse: [2]f32, a, b: ^Rect) -> bool {
		step(ctx, mouse, {}, a, b)
		step(ctx, mouse, {}, a, b)
		step(ctx, mouse, {.Left}, a, b)
		return step(ctx, mouse, {}, a, b)
	}

	testing.expect(t, !click(&ctx, on_button, &a, &b))

	click(&ctx, {5, 150}, &a, &b)
	testing.expect_value(t, ctx.panel_order[len(ctx.panel_order) - 1], get_id(&ctx, "a"))

	testing.expect(t, click(&ctx, on_button, &a, &b))
}

@(test)
test_scale :: proc(t: ^testing.T) {
	ctx: Context
	init(&ctx, fake_measure, 0, 2)
	defer destroy(&ctx)

	begin(&ctx, {})
	r := next_rect(&ctx, {10, 10})
	end(&ctx)

	testing.expect_value(t, ctx.theme.font_size, 32)
	testing.expect_value(t, r.pos, [2]f32{PADDING * 2, PADDING * 2})
}