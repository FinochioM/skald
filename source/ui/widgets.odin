package ui

import "core:fmt"
import "core:strings"

import "skald:platform"

label :: proc(ctx: ^Context, text: string) {
	size := ctx.measure(ctx.font, text, ctx.theme.font_size)
	r := next_rect(ctx, size)
	push_text(ctx, text, r.pos, ctx.theme.text)
}

button :: proc(ctx: ^Context, text: string) -> bool {
	id := get_id(ctx, text)
	text_size := ctx.measure(ctx.font, text, ctx.theme.font_size)
	r := next_rect(ctx, text_size + 2 * ctx.theme.padding)

	clicked := update_control(ctx, id, r)

	push_rect(ctx, r, control_color(ctx, id))
	push_text(ctx, text, r.pos + ctx.theme.padding, ctx.theme.text)
	return clicked
}

@(private)
control_color :: proc(ctx: ^Context, id: Id) -> platform.Color {
	if ctx.active == id {
		return ctx.theme.button_active
	} else if ctx.hot == id {
		return ctx.theme.button_hot
	}
	return ctx.theme.button
}

checkbox :: proc(ctx: ^Context, text: string, value: ^bool) -> (changed: bool) {
	id := get_id(ctx, text)
	box := ctx.theme.font_size
	text_size := ctx.measure(ctx.font, text, ctx.theme.font_size)
	r := next_rect(ctx, {box + ctx.theme.spacing + text_size.x, max(box, text_size.y)})

	if update_control(ctx, id, r) {
		value^ = !value^
		changed = true
	}

	push_rect(ctx, {r.pos, box}, control_color(ctx, id))
	if value^ {
		push_rect(ctx, {r.pos + box / 4, box / 2}, ctx.theme.accent)
	}
	push_text(ctx, text, r.pos + {box + ctx.theme.spacing, 0}, ctx.theme.text)
	return
}

slider :: proc(ctx: ^Context, text: string, value: ^f32, lo, hi: f32) -> (changed: bool) {
	id := get_id(ctx, text)
	r := next_rect(ctx, {ctx.theme.slider_width, ctx.theme.font_size + 2 * ctx.theme.padding})

	update_control(ctx, id, r)
	if ctx.active == id {
		t := clamp((ctx.mouse.x - r.pos.x) / r.size.x, 0, 1)
		v := lo + t * (hi - lo)
		changed = v != value^
		value^ = v
	}

	fill := clamp((value^ - lo) / (hi - lo), 0, 1)
	push_rect(ctx, r, control_color(ctx, id))
	push_rect(ctx, {r.pos, {r.size.x * fill, r.size.y}}, ctx.theme.accent)
	push_text(ctx, fmt.tprintf("%s: %.2f", text, value^), r.pos + ctx.theme.padding, ctx.theme.text)
	return
}

text_field :: proc(ctx: ^Context, label: string, text: ^strings.Builder) -> (changed: bool) {
	id := get_id(ctx, label)
	pad := ctx.theme.padding
	r := next_rect(ctx, {ctx.theme.field_width, ctx.theme.font_size + 2 * pad})

	update_control(ctx, id, r)
	if ctx.active == id && .Left in ctx.mouse_pressed {
		ctx.focus = id
	}

	focused := ctx.focus == id
	if focused {
		if ctx.text != "" {
			strings.write_string(text, ctx.text)
			changed = true
		}
		if .Backspace in ctx.keys && strings.builder_len(text^) > 0 {
			strings.pop_rune(text)
			changed = true
		}
		if .Enter in ctx.keys || .Escape in ctx.keys {
			ctx.focus = 0
		}
	}

	push_rect(ctx, r, focused ? ctx.theme.button_active : control_color(ctx, id))

	s := strings.to_string(text^)
	width := ctx.measure(ctx.font, s, ctx.theme.font_size).x
	scroll := max(width - (r.size.x - 2 * pad), 0)

	push_clip(ctx, r)
	if s == "" && !focused {
		hint := ctx.theme.text
		hint.a = 110
		push_text(ctx, label, r.pos + pad, hint)
	} else {
		push_text(ctx, s, r.pos + pad - {scroll, 0}, ctx.theme.text)
	}
	if focused {
		caret := Rect{r.pos + {pad + width - scroll, pad}, {max(1, ctx.scale), ctx.theme.font_size}}
		push_rect(ctx, caret, ctx.theme.accent)
	}
	pop_clip(ctx)

	return
}