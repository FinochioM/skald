package main

import "skald:backend_raylib"
import "skald:platform"

BACKEND_NAME :: #config(SKALD_BACKEND, "raylib")

when BACKEND_NAME == "raylib" {
	pf :: backend_raylib.BACKEND
} else {
	#panic("unknown SKALD_BACKEND: " + BACKEND_NAME)
}

TICK_RATE :: 60
TICK_DT :: 1.0 / TICK_RATE

Box :: struct {
	pos: [2]f32,
	prev_pos: [2]f32,
	vel: [2]f32,
}

BOX_SIZE :: 32
ORANGE :: platform.Color{255,161,0,255}

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
	pf.init(1280, 720, "skald")	

	state.box = Box {
		pos = {100, 100},
		vel = {240, 180},
	}
	state.box.prev_pos = state.box.pos
}

step :: proc() -> bool {
	if pf.should_close() {
		return false
	}


	state.accumulator += f64(pf.frame_time())
	state.accumulator = min(state.accumulator, 0.25)

	for state.accumulator >= TICK_DT {
		tick(&state.box)
		state.accumulator -= TICK_DT
	}

	alpha := f32(state.accumulator / TICK_DT)
	box := state.box
	draw_pos := box.prev_pos + (box.pos - box.prev_pos) * alpha
	
	pf.begin_frame()
	pf.clear({30, 30, 30, 255})

	pf.draw_rect(draw_pos, BOX_SIZE, ORANGE)

	pf.end_frame()

	return true
}

shutdown :: proc() {
	pf.shutdown()
}

tick :: proc(b: ^Box) {
	b.prev_pos = b.pos
	b.pos += b.vel * TICK_DT
	
	screen := pf.screen_size()
	w := f32(screen.x) - BOX_SIZE
	h := f32(screen.y) - BOX_SIZE

	if b.pos.x < 0 || b.pos.x > w {
		b.vel.x = -b.vel.x
		b.pos.x = clamp(b.pos.x, 0, w)
	}

	if b.pos.y < 0 || b.pos.y > h {
		b.vel.y = -b.vel.y
		b.pos.y = clamp(b.pos.y, 0, h)
	}
}
