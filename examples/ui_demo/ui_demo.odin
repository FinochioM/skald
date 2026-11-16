package ui_demo

import "base:runtime"
import "core:fmt"

import "skald:skald"
import "skald:ui"

TEXT_SIZE :: 16

State :: struct {
	pf: ^skald.Platform,
	font: skald.Font,
	ui: ui.Context,
	clicks: int,
}

state: ^State

@(export)
game_init :: proc(pf: ^skald.Platform) {
	state = new(State)
	state.pf = pf

	size := TEXT_SIZE * pf.dpi_scale()
	state.font = ui.load_default_font(pf, size)
	ui.init(&state.ui, pf.measure_text, state.font, size)
}

@(export)
game_step :: proc() {
	pf := state.pf
	ctx := &state.ui

	ui.begin(ctx, {mouse = pf.mouse_position(), down = pf.mouse_down()})

	ui.label(ctx, "skald ui")
	if ui.button(ctx, "click me") {
		state.clicks += 1
	}
	ui.label(ctx, fmt.tprintf("clicked %d times", state.clicks))
	if ui.button(ctx, "reset") {
		state.clicks = 0
	}

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
}