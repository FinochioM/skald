package main

import rl "vendor:raylib"

TICK_RATE :: 60
TICK_DT :: 1.0 / TICK_RATE

Box :: struct {
	pos: [2]f32,
	prev_pos: [2]f32,
	vel: [2]f32,
}

BOX_SIZE :: 32

State :: struct {
	box: Box,
	accumulator: f64,
}

state: State

main :: proc() {
	init()
	for step() {}
	shutdown()
}

init :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1280, 720, "skald")

	state.box = Box {
		pos = {100, 100},
		vel = {240, 180},
	}
	state.box.prev_pos = state.box.pos
}

step :: proc() -> bool {
	if rl.WindowShouldClose() {
		return false
	}


	state.accumulator += f64(rl.GetFrameTime())
	state.accumulator = min(state.accumulator, 0.25)

	for state.accumulator >= TICK_DT {
		tick(&state.box)
		state.accumulator -= TICK_DT
	}

	alpha := f32(state.accumulator / TICK_DT)
	box := state.box
	draw_pos := box.prev_pos + (box.pos - box.prev_pos) * alpha

	rl.BeginDrawing()
	rl.ClearBackground({30, 30, 30, 255})

	rl.DrawRectangleV(draw_pos, BOX_SIZE, rl.ORANGE)
	rl.DrawFPS(20, 20)

	rl.EndDrawing()

	return true
}

shutdown :: proc() {
	rl.CloseWindow()
}

tick :: proc(b: ^Box) {
	b.prev_pos = b.pos
	b.pos += b.vel * TICK_DT

	w := f32(rl.GetScreenWidth()) - BOX_SIZE
	h := f32(rl.GetScreenHeight()) - BOX_SIZE

	if b.pos.x < 0 || b.pos.x > w {
		b.vel.x = -b.vel.x
		b.pos.x = clamp(b.pos.x, 0, w)
	}

	if b.pos.y < 0 || b.pos.y > h {
		b.vel.y = -b.vel.y
		b.pos.y = clamp(b.pos.y, 0, h)
	}
}
