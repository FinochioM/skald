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

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1280, 720, "skald")

	defer rl.CloseWindow()

	box := Box {
		pos = {100, 100},
		vel = {240, 180},
	}
	box.prev_pos = box.pos

	accumulator: f64

	for !rl.WindowShouldClose() {
		accumulator += f64(rl.GetFrameTime())

		accumulator = min(accumulator, 0.25)

		for accumulator >= TICK_DT {
			tick(&box)
			accumulator -= TICK_DT
		}

		alpha := f32(accumulator / TICK_DT)
		draw_pos := box.prev_pos + (box.pos - box.prev_pos) * alpha

		rl.BeginDrawing()
		rl.ClearBackground({30, 30, 30, 255})

		rl.DrawRectangleV(draw_pos, BOX_SIZE, rl.ORANGE)
		rl.DrawFPS(20, 20)

		rl.EndDrawing()
	}
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
