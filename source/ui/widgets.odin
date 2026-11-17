package ui

import "core:fmt"

import "skald:platform"

TEXT_COLOR :: platform.Color{220, 220, 225, 255}
BUTTON_COLOR :: platform.Color{60, 60, 70, 255}
BUTTON_HOT :: platform.Color{75, 75, 90, 255}
BUTTON_ACTIVE :: platform.Color{45, 45, 55, 255}
ACCENT_COLOR :: platform.Color{90, 140, 220, 255}
SLIDER_WIDTH :: 200

label :: proc(ctx: ^Context, text: string) {
	size := ctx.measure(ctx.font, text, ctx.font_size)
	r := next_rect(ctx, size)
	push_text(ctx, text, r.pos, TEXT_COLOR)
}

button :: proc(ctx: ^Context, text: string) -> bool {
	id := get_id(ctx, text)
	text_size := ctx.measure(ctx.font, text, ctx.font_size)
	r := next_rect(ctx, text_size + 2 * PADDING)

	clicked := update_control(ctx, id, r)

	push_rect(ctx, r, control_color(ctx, id))
	push_text(ctx, text, r.pos + PADDING, TEXT_COLOR)
	return clicked
}

@(private)
control_color :: proc(ctx: ^Context, id: Id) -> platform.Color {
	if ctx.active == id {
		return BUTTON_ACTIVE
	} else if ctx.hot == id {
		return BUTTON_HOT
	}
	return BUTTON_COLOR
}

checkbox :: proc(ctx: ^Context, text: string, value: ^bool) -> (changed: bool) {
	id := get_id(ctx, text)
	box := ctx.font_size
	text_size := ctx.measure(ctx.font, text, ctx.font_size)
	r := next_rect(ctx, {box + SPACING + text_size.x, max(box, text_size.y)})

	if update_control(ctx, id, r) {
		value^ = !value^
		changed = true
	}

	push_rect(ctx, {r.pos, box}, control_color(ctx, id))
	if value^ {
		push_rect(ctx, {r.pos + box / 4, box / 2}, ACCENT_COLOR)
	}
	push_text(ctx, text, r.pos + {box + SPACING, 0}, TEXT_COLOR)
	return
}

slider :: proc(ctx: ^Context, text: string, value: ^f32, lo, hi: f32) -> (changed: bool) {
	id := get_id(ctx, text)
	r := next_rect(ctx, {SLIDER_WIDTH, ctx.font_size + 2 * PADDING})

	update_control(ctx, id, r)
	if ctx.active == id {
		t := clamp((ctx.mouse.x - r.pos.x) / r.size.x, 0, 1)
		v := lo + t * (hi - lo)
		changed = v != value^
		value^ = v
	}

	fill := clamp((value^ - lo) / (hi - lo), 0, 1)
	push_rect(ctx, r, control_color(ctx, id))
	push_rect(ctx, {r.pos, {r.size.x * fill, r.size.y}}, ACCENT_COLOR)
	push_text(ctx, fmt.tprintf("%s: %.2f", text, value^), r.pos + PADDING, TEXT_COLOR)
	return
}