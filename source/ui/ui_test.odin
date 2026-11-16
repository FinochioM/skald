package ui

import "core:testing"

import "skald:platform"

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
	init(&ctx, fake_measure, 0, 16)
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
	init(&ctx, fake_measure, 0, 16)
	defer destroy(&ctx)

	a := get_id(&ctx, "ok")
	push_id(&ctx, "panel")
	b := get_id(&ctx, "ok")
	pop_id(&ctx)

	testing.expect(t, a != b)
	testing.expect(t, a == get_id(&ctx, "ok"))
}