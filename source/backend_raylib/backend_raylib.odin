package backend_raylib

import "skald:platform"
import "core:strings"
import rl "vendor:raylib"

BACKEND :: platform.Interface {
	init = init,
	shutdown = shutdown,
	should_close = should_close,
	frame_time = frame_time,
	keys_down = keys_down,
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

keys_down :: proc() -> platform.Key_Set {
	down: platform.Key_Set
	for rk, k in KEY_MAP {
		if rl.IsKeyDown(rk) {
			down += {k}
		}
	}

	return down
}

@(private)
KEY_MAP := [platform.Key]rl.KeyboardKey {
	.A = .A, .B = .B, .C = .C, .D = .D, .E = .E, .F = .F, .G = .G,
	.H = .H, .I = .I, .J = .J, .K = .K, .L = .L, .M = .M, .N = .N,
	.O = .O, .P = .P, .Q = .Q, .R = .R, .S = .S, .T = .T, .U = .U,
	.V = .V, .W = .W, .X = .X, .Y = .Y, .Z = .Z,
	.Num_0 = .ZERO, .Num_1 = .ONE, .Num_2 = .TWO, .Num_3 = .THREE, .Num_4 = .FOUR,
	.Num_5 = .FIVE, .Num_6 = .SIX, .Num_7 = .SEVEN, .Num_8 = .EIGHT, .Num_9 = .NINE,
	.Up = .UP, .Down = .DOWN, .Left = .LEFT, .Right = .RIGHT,
	.Space = .SPACE, .Enter = .ENTER, .Escape = .ESCAPE, .Tab = .TAB, .Backspace = .BACKSPACE,
	.Left_Shift = .LEFT_SHIFT, .Left_Control = .LEFT_CONTROL, .Left_Alt = .LEFT_ALT,
}
