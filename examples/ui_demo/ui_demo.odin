package ui_demo

import "base:runtime"
import "core:fmt"

import "skald:skald"
import "skald:ui"

TEXT_SIZE :: 16

Rect :: ui.Rect
State :: struct {
	pf: ^skald.Platform,
	font: skald.Font,
	ui: ui.Context,
	clicks: int,
	show_extra: bool,
	volume: f32,
	main_panel: Rect,
	list_panel: Rect,
}

state: ^State

@(export)
game_init :: proc(pf: ^skald.Platform) {
	state = new(State)
	state.pf = pf

	size := TEXT_SIZE * pf.dpi_scale()
	state.font = ui.load_default_font(pf, size)
	ui.init(&state.ui, pf.measure_text, state.font, size)

	place_panels()
}

@(export)
game_step :: proc() {
	pf := state.pf
	ctx := &state.ui

	ui.begin(ctx, {mouse = pf.mouse_position(), down = pf.mouse_down()})

	main_panel(ctx)
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
	if state.main_panel.size == 0 {
		state.main_panel = {{20, 20}, {420, 260}}
	}
	if state.list_panel.size == 0 {
		state.list_panel = {{460, 20}, {240, 200}}
	}
}

main_panel :: proc(ctx: ^ui.Context) {
	ui.panel(ctx, "skald ui", &state.main_panel)

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