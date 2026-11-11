package backend_raylib

import "skald:platform"
import "core:strings"
import rl "vendor:raylib"

BACKEND :: platform.Interface {
	init = init,
	shutdown = shutdown,
	should_close = should_close,
	frame_time = frame_time,
	screen_size = screen_size,
	begin_frame = begin_frame,
	end_frame = end_frame,
	clear = clear,
	draw_rect = draw_rect,
}

init :: proc(width, height: int, title: string) {
	rl.SetTraceLogLevel(.WARNING)
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})

	rl.InitWindow(i32(width), i32(height), cstr(title))
}

shutdown :: proc() {
	rl.CloseWindow()
}

should_close :: proc() -> bool {
	return rl.WindowShouldClose()
}

frame_time :: proc() -> f64 {
	return f64(rl.GetFrameTime())
}

screen_size :: proc() -> [2]int {
	return {int(rl.GetScreenWidth()), int(rl.GetScreenHeight())}
}

begin_frame :: proc() {
	rl.BeginDrawing()
}

end_frame :: proc() {
	rl.EndDrawing()
}

clear :: proc(color: platform.Color) {
	rl.ClearBackground(rl.Color(color))
}

draw_rect :: proc(pos, size: [2]f32, color: platform.Color) {
	rl.DrawRectangleV(pos, size, rl.Color(color))
}

@(private)
cstr :: proc(s: string) -> cstring {
	return strings.clone_to_cstring(s, context.temp_allocator)
}
