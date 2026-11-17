package ui_demo

import "base:runtime"
import "core:fmt"
import "core:strings"

import "skald:skald"
import "skald:ui"

Rect :: ui.Rect
State :: struct {
	pf: ^skald.Platform,
	font: skald.Font,
	ui: ui.Context,
	clicks: int,
	show_extra: bool,
	volume: f32,
	list_panel: Rect,
	big: bool,
	name: strings.Builder,
	left_split: f32,
	right_split: f32,
	bottom_split: f32,
}

state: ^State

@(export)
game_init :: proc(pf: ^skald.Platform) {
	state = new(State)
	state.pf = pf

	scale := pf.dpi_scale()
	state.font = ui.load_default_font(pf, ui.DEFAULT_THEME.font_size * scale)
	ui.init(&state.ui, pf.measure_text, state.font, scale)

	place_panels()
}

@(export)
game_step :: proc() {
	pf := state.pf
	ctx := &state.ui

	if scale := pf.dpi_scale() * (state.big ? 2 : 1); scale != ctx.scale {
		rescale(scale)
	}

	ui.begin(ctx, {
		mouse = pf.mouse_position(),
		down = pf.mouse_down(),
		text = pf.text_input(),
		keys = pf.keys_pressed(),
	})

	size := pf.screen_size()
	screen := Rect{{0, 0}, {f32(size.x), f32(size.y)}}
	left, rest := ui.split(ctx, "left split", screen, .Row, &state.left_split)
	center, right := ui.split(ctx, "right split", rest, .Row, &state.right_split)
	view, bottom := ui.split(ctx, "bottom split", center, .Column, &state.bottom_split)

	outliner(ctx, left)
	inspector(ctx, right)
	console(ctx, bottom)
	viewport(ctx, view)

	list_panel(ctx)

	ui.end(ctx)

	pf.begin_frame()
	pf.clear({24, 24, 28, 255})
	ui.draw(ctx, pf)
	pf.end_frame()

	free_all(context.temp_allocator)
}

@(export)
game_shutdown :: proc() {
	ui.destroy(&state.ui)
	strings.builder_destroy(&state.name)
	state.pf.unload_font(state.font)
	free(state)
}

@(export)
game_memory :: proc() -> rawptr {
	return state
}

@(export)
game_memory_type :: proc() -> ^runtime.Type_Info {
	return type_info_of(State)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	state = (^State)(mem)
	place_panels()
}

place_panels :: proc() {
	if state.left_split == 0 {
		state.left_split = 0.2
		state.right_split = 0.7
		state.bottom_split = 0.75
	}
	if state.list_panel.size == 0 {
		state.list_panel = {{460, 20}, {240, 200}}
	}
}

outliner :: proc(ctx: ^ui.Context, r: Rect) {
	ui.dock(ctx, "outliner", r)

	for i in 0 ..< 30 {
		ui.label(ctx, fmt.tprintf("thing %d", i))
	}
}

console :: proc(ctx: ^ui.Context, r: Rect) {
	ui.dock(ctx, "console", r)

	ui.label(ctx, "built build/debug/games/ui_demo.so")
	ui.label(ctx, "drag the dividers between docks")
}

viewport :: proc(ctx: ^ui.Context, r: Rect) {
	ui.push_rect(ctx, r, {16, 16, 20, 255})
	ui.push_text(ctx, "viewport", r.pos + ctx.theme.padding, ctx.theme.text)
}

inspector :: proc(ctx: ^ui.Context, r: Rect) {
	ui.dock(ctx, "inspector", r)

	ui.text_field(ctx, "name", &state.name)
	ui.label(ctx, fmt.tprintf("hello, %s", strings.to_string(state.name)))

	{
		ui.row(ctx)
		if ui.button(ctx, "click me") {
			state.clicks += 1
		}
		if ui.button(ctx, "reset") {
			state.clicks = 0
		}
		ui.label(ctx, fmt.tprintf("clicked %d times", state.clicks))
	}

	ui.checkbox(ctx, "2x (fake 200%)", &state.big)

	ui.checkbox(ctx, "show extra", &state.show_extra)
	if state.show_extra {
		ui.slider(ctx, "volume", &state.volume, 0, 1)
		ui.label(ctx, "hidden until the box is ticked")
	}
}

list_panel :: proc(ctx: ^ui.Context) {
	ui.panel(ctx, "list", &state.list_panel)

	for i in 0 ..< 20 {
		ui.label(ctx, fmt.tprintf("item %d", i))
	}
}

rescale :: proc(scale: f32) {
	pf := state.pf
	old := state.ui.scale

	pf.unload_font(state.font)
	state.font = ui.load_default_font(pf, ui.DEFAULT_THEME.font_size * scale)
	ui.set_scale(&state.ui, state.font, scale)

	if old > 0 {
		state.list_panel.pos *= scale / old
		state.list_panel.size *= scale / old
	}
}