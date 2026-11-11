package platform

// what the engine uses from the os and the gpu

Interface :: struct #all_or_none {
	init: proc(width, height:int, title:string),
	shutdown: proc(),

	should_close: proc() -> bool,

	frame_time: proc() -> f64,
	keys_down: proc() -> Key_Set,
	screen_size: proc() -> [2]int,

	begin_frame: proc(),
	end_frame: proc(),
	clear: proc(color:Color),
	draw_rect: proc(pos, size: [2]f32, color: Color),
	draw_text: proc(text: string, pos: [2]f32, size: f32, color: Color),
}

Color :: [4]u8