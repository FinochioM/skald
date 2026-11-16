package ui_demo

import "base:runtime"

import "skald:skald"
import "skald:ui"

TEXT_SIZE :: 16
TITLE_SIZE :: 32

State :: struct {
	pf: ^skald.Platform,
	font: skald.Font,
	title_font: skald.Font,
}

state: ^State

@(export)
game_init :: proc(pf: ^skald.Platform) {
	state = new(State)
	state.pf = pf

	scale := pf.dpi_scale()
	state.font = ui.load_default_font(pf, TEXT_SIZE * scale)
	state.title_font = ui.load_default_font(pf, TITLE_SIZE * scale)
}

@(export)
game_step :: proc() {
	pf := state.pf
	scale := pf.dpi_scale()
	white := skald.Color{230, 230, 230, 255}

	pf.begin_frame()
	pf.clear({24, 24, 28, 255})

	pf.draw_text(state.title_font, "skald ui", {20, 20} * scale, TITLE_SIZE * scale, white)
	pf.draw_text(state.font, "fira code 16 ñandú, café, 0O 1lI {}[]", {20, 70} * scale, TEXT_SIZE * scale, white)
	pf.draw_text(skald.DEFAULT_FONT, "built-in 16 to compare", {20, 100} * scale, TEXT_SIZE * scale, white)

	pf.end_frame()

	free_all(context.temp_allocator)
}

@(export)
game_shutdown :: proc() {
	state.pf.unload_font(state.font)
	state.pf.unload_font(state.title_font)
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