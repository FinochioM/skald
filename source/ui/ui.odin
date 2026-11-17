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

Clip :: struct {
	rect: Rect,
	enabled: bool,
}

Command :: union {
	Draw_Rect,
	Draw_Text,
	Clip,
}

Direction :: enum u8 {
	Column,
	Row,
}

Layout :: struct {
	dir: Direction,
	start: [2]f32,
	cursor: [2]f32,
	extent: [2]f32,
}

Panel_Range :: struct {
	id: Id,
	rect: Rect,
	first: int,
	last: int,
}

Measure_Text :: proc(font: platform.Font, text: string, size: f32) -> [2]f32

Context :: struct {
	measure: Measure_Text,
	font: platform.Font,
	theme: Theme,
	scale: f32,

	mouse: [2]f32,
	mouse_down: platform.Mouse_Buttons,
	mouse_pressed: platform.Mouse_Buttons,
	mouse_released: platform.Mouse_Buttons,

	hot: Id,
	next_hot: Id,
	active: Id,

	id_stack: [dynamic]Id,
	layouts: [dynamic]Layout,
	clips: [dynamic]Rect,
	drag_offset: [2]f32,

	panels: [dynamic]Panel_Range,
	panel_order: [dynamic]Id,
	panel: Id,
	hover_panel: Id,
	commands: [dynamic]Command,
}

init :: proc(ctx: ^Context, measure: Measure_Text, font: platform.Font, scale: f32, allocator := context.allocator) {
	ctx^ = {
		measure = measure,
		id_stack = make([dynamic]Id, allocator),
		layouts = make([dynamic]Layout, allocator),
		clips = make([dynamic]Rect, allocator),
		commands = make([dynamic]Command, allocator),
		panels = make([dynamic]Panel_Range, allocator),
		panel_order = make([dynamic]Id, allocator),
	}

	set_scale(ctx, font, scale)
}

destroy :: proc(ctx: ^Context) {
	delete(ctx.id_stack)
	delete(ctx.layouts)
	delete(ctx.clips)
	delete(ctx.commands)
	delete(ctx.panels)
	delete(ctx.panel_order)
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
	clear(&ctx.layouts)
	clear(&ctx.clips)
	clear(&ctx.panels)
	ctx.panel = 0
	append(&ctx.layouts, Layout{.Column, ctx.theme.padding, ctx.theme.padding, ctx.theme.padding})
}

end :: proc(ctx: ^Context) {
	if .Left not_in ctx.mouse_down {
		ctx.active = 0
	}

	keep := 0
	for id in ctx.panel_order {
		if find_panel(ctx, id) >= 0 {
			ctx.panel_order[keep] = id
			keep += 1
		}
	}
	resize(&ctx.panel_order, keep)
	for p in ctx.panels {
		if !in_order(ctx, p.id) {
			append(&ctx.panel_order, p.id)
		}
	}

	ctx.hover_panel = 0
	#reverse for id, i in ctx.panel_order {
		if rect_contains(ctx.panels[find_panel(ctx, id)].rect, ctx.mouse) {
			ctx.hover_panel = id
			if .Left in ctx.mouse_pressed {
				ordered_remove(&ctx.panel_order, i)
				append(&ctx.panel_order, id)
			}
			break
		}
	}
}

@(private)
find_panel :: proc(ctx: ^Context, id: Id) -> int {
	for p, i in ctx.panels {
		if p.id == id {
			return i
		}
	}
	return -1
}

@(private)
in_order :: proc(ctx: ^Context, id: Id) -> bool {
	for o in ctx.panel_order {
		if o == id {
			return true
		}
	}
	return false
}

draw :: proc(ctx: ^Context, pf: ^platform.Interface) {
	from := 0
	for p in ctx.panels {
		replay(ctx.commands[from:p.first], pf)
		from = p.last
	}
	replay(ctx.commands[from:], pf)

	for id in ctx.panel_order {
		p := ctx.panels[find_panel(ctx, id)]
		replay(ctx.commands[p.first:p.last], pf)
	}
}

@(private)
replay :: proc(commands: []Command, pf: ^platform.Interface) {
	for cmd in commands {
		switch c in cmd {
		case Draw_Rect:
			pf.draw_rect(c.rect.pos, c.rect.size, c.color)
		case Clip:
			if c.enabled {
				pf.begin_clip(c.rect.pos, c.rect.size)
			} else {
				pf.end_clip()
			}
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
	l := &ctx.layouts[len(ctx.layouts) - 1]
	r := Rect{l.cursor, size}

	switch l.dir {
	case .Column:
		l.cursor.y += size.y + ctx.theme.spacing
	case .Row:
		l.cursor.x += size.x + ctx.theme.spacing
	}
	l.extent = {max(l.extent.x, r.pos.x + size.x), max(l.extent.y, r.pos.y + size.y)}

	return r
}

begin_layout :: proc(ctx: ^Context, dir: Direction) {
	cursor := ctx.layouts[len(ctx.layouts) - 1].cursor
	append(&ctx.layouts, Layout{dir, cursor, cursor, cursor})
}

end_layout :: proc(ctx: ^Context) {
	assert(len(ctx.layouts) > 1, "end_layout without begin_layout")
	l := pop(&ctx.layouts)
	next_rect(ctx, l.extent - l.start)
}

@(deferred_in=end_layout)
row :: proc(ctx: ^Context) {
	begin_layout(ctx, .Row)
}

@(deferred_in=end_layout)
column :: proc(ctx: ^Context) {
	begin_layout(ctx, .Column)
}

rect_contains :: proc(r: Rect, p: [2]f32) -> bool {
	return p.x >= r.pos.x && p.y >= r.pos.y && p.x < r.pos.x + r.size.x && p.y < r.pos.y + r.size.y
}

update_control :: proc(ctx: ^Context, id: Id, r: Rect) -> (clicked: bool) {
	over := rect_contains(r, ctx.mouse) && ctx.panel == ctx.hover_panel
	
	if len(ctx.clips) > 0 {
		over &&= rect_contains(ctx.clips[len(ctx.clips) - 1], ctx.mouse)
	}

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
	append(&ctx.commands, Draw_Text{ctx.font, text, pos, ctx.theme.font_size, color})
}

rect_intersect :: proc(a, b: Rect) -> Rect {
	lo := [2]f32{max(a.pos.x, b.pos.x), max(a.pos.y, b.pos.y)}
	hi := [2]f32{min(a.pos.x + a.size.x, b.pos.x + b.size.x), min(a.pos.y + a.size.y, b.pos.y + b.size.y)}
	return {lo, {max(hi.x - lo.x, 0), max(hi.y - lo.y, 0)}}
}

push_clip :: proc(ctx: ^Context, r: Rect) {
	r := r
	if len(ctx.clips) > 0 {
		r = rect_intersect(r, ctx.clips[len(ctx.clips) - 1])
	}
	append(&ctx.clips, r)
	append(&ctx.commands, Clip{r, true})
}

pop_clip :: proc(ctx: ^Context) {
	pop(&ctx.clips)
	if len(ctx.clips) > 0 {
		append(&ctx.commands, Clip{ctx.clips[len(ctx.clips) - 1], true})
	} else {
		append(&ctx.commands, Clip{})
	}
}