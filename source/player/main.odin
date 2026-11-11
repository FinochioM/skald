package main

import rl "vendor:raylib"

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1280, 720, "skald")

	defer rl.CloseWindow()

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground({30, 30, 30, 255})
		rl.DrawText("hello", 20, 20, 20, rl.RAYWHITE)
		rl.EndDrawing()
	}
}
