package ui

import "skald:platform"

TEXT_COLOR :: platform.Color{220, 220, 225, 255}
BUTTON_COLOR :: platform.Color{60, 60, 70, 255}
BUTTON_HOT :: platform.Color{75, 75, 90, 255}
BUTTON_ACTIVE :: platform.Color{45, 45, 55, 255}

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

	color := BUTTON_COLOR
	if ctx.active == id {
		color = BUTTON_ACTIVE
	} else if ctx.hot == id {
		color = BUTTON_HOT
	}

	push_rect(ctx, r, color)
	push_text(ctx, text, r.pos + PADDING, TEXT_COLOR)
	return clicked
}