package backend_nil

import "skald:platform"

FRAMES :: #config(SKALD_NIL_FRAMES, 600)

BACKEND :: platform.Interface {
	init         = init,
	shutdown     = shutdown,
	should_close = should_close,
	frame_time   = frame_time,
	keys_down    = keys_down,
	screen_size  = screen_size,
	mouse_position = mouse_position,
	mouse_down = mouse_down,
	mouse_wheel = mouse_wheel,
	text_input = text_input,
	begin_frame  = begin_frame,
	end_frame    = end_frame,
	clear        = clear,
	draw_rect    = draw_rect,
	draw_text    = draw_text,
}

@(private)
frame_count: int

init :: proc(width, height: int, title: string) {
	frame_count = 0
}

shutdown :: proc() {}

should_close :: proc() -> bool {
	return frame_count >= FRAMES
}

frame_time :: proc() -> f64 {
	return 1.0 / 60
}

keys_down :: proc() -> platform.Key_Set {
	return {}
}

screen_size :: proc() -> [2]int {
	return {1280, 720}
}

begin_frame :: proc() {}

end_frame :: proc() {
	frame_count += 1
}

clear :: proc(color: platform.Color) {}

draw_rect :: proc(pos, size: [2]f32, color: platform.Color) {}
draw_text :: proc(text: string, pos: [2]f32, size: f32, color: platform.Color) {}

mouse_position :: proc() -> [2]f32 {
	return {}
}

mouse_down :: proc() -> platform.Mouse_Buttons {
	return {}
}

mouse_wheel :: proc() -> [2]f32 {
	return {}
}

text_input :: proc() -> string {
	return ""
}