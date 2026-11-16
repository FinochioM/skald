package ui

import "core:hash"

import "skald:platform"

Id :: distinct u64

Rect :: struct {
	pos: [2]f32,
	size: [2]f32,
}

Input :: struct {
	mouse: [2]f32,
	down: platform.Mouse_Buttons,
}

Draw_Rect :: struct {
	rect: Rect,
	color: platform.Color,
}

Draw_Text :: struct {
	font: platform.Font,
	text: string,
	pos: [2]f32,
	size: f32,
	color: platform.Color,
}

Command :: union {
	Draw_Rect,
	Draw_Text,
}

Measure_Text :: proc(font: platform.Font, text: string, size: f32) -> [2]f32

Context :: struct {
	measure: Measure_Text,
	font: platform.Font,
	font_size: f32,

	mouse: [2]f32,
	mouse_down: platform.Mouse_Buttons,
	mouse_pressed: platform.Mouse_Buttons,
	mouse_released: platform.Mouse_Buttons,

	hot: Id,
	next_hot: Id,
	active: Id,

	id_stack: [dynamic]Id,
	cursor: [2]f32,
	commands: [dynamic]Command,
}

PADDING :: 8
SPACING :: 6

init :: proc(ctx: ^Context, measure: Measure_Text, font: platform.Font, font_size: f32, allocator := context.allocator) {
	ctx^ = {
		measure = measure,
		font = font,
		font_size = font_size,
		id_stack = make([dynamic]Id, allocator),
		commands = make([dynamic]Command, allocator),
	}
}

destroy :: proc(ctx: ^Context) {
	delete(ctx.id_stack)
	delete(ctx.commands)
}

begin :: proc(ctx: ^Context, input: Input) {
	ctx.mouse_pressed = input.down - ctx.mouse_down
	ctx.mouse_released = ctx.mouse_down - input.down
	ctx.mouse_down = input.down
	ctx.mouse = input.mouse

	ctx.hot = ctx.next_hot
	ctx.next_hot = 0

	clear(&ctx.id_stack)
	clear(&ctx.commands)
	ctx.cursor = {PADDING, PADDING}
}

end :: proc(ctx: ^Context) {
	if .Left not_in ctx.mouse_down {
		ctx.active = 0
	}
}

draw :: proc(ctx: ^Context, pf: ^platform.Interface) {
	for cmd in ctx.commands {
		switch c in cmd {
		case Draw_Rect:
			pf.draw_rect(c.rect.pos, c.rect.size, c.color)
		case Draw_Text:
			pf.draw_text(c.font, c.text, c.pos, c.size, c.color)
		}
	}
}

get_id :: proc(ctx: ^Context, label: string) -> Id {
	seed := u64(0xcbf29ce484222325)
	if len(ctx.id_stack) > 0 {
		seed = u64(ctx.id_stack[len(ctx.id_stack) - 1])
	}
	return Id(hash.fnv64a(transmute([]u8)label, seed))
}

push_id :: proc(ctx: ^Context, label: string) {
	append(&ctx.id_stack, get_id(ctx, label))
}

pop_id :: proc(ctx: ^Context) {
	pop(&ctx.id_stack)
}

next_rect :: proc(ctx: ^Context, size: [2]f32) -> Rect {
	r := Rect{ctx.cursor, size}
	ctx.cursor.y += size.y + SPACING
	return r
}

rect_contains :: proc(r: Rect, p: [2]f32) -> bool {
	return p.x >= r.pos.x && p.y >= r.pos.y && p.x < r.pos.x + r.size.x && p.y < r.pos.y + r.size.y
}

update_control :: proc(ctx: ^Context, id: Id, r: Rect) -> (clicked: bool) {
	over := rect_contains(r, ctx.mouse)
	if over && (ctx.active == 0 || ctx.active == id) {
		ctx.next_hot = id
	}

	if ctx.hot == id && .Left in ctx.mouse_pressed {
		ctx.active = id
	}

	if ctx.active == id && .Left in ctx.mouse_released {
		clicked = over
		ctx.active = 0
	}

	return
}

push_rect :: proc(ctx: ^Context, r: Rect, color: platform.Color) {
	append(&ctx.commands, Draw_Rect{r, color})
}

push_text :: proc(ctx: ^Context, text: string, pos: [2]f32, color: platform.Color) {
	append(&ctx.commands, Draw_Text{ctx.font, text, pos, ctx.font_size, color})
}