package platform

// what the engine uses from the os and the gpu

Interface :: struct #all_or_none {
	init: proc(width, height:int, title:string),
	shutdown: proc(),

	should_close: proc() -> bool,

	frame_time: proc() -> f64,
	screen_size: proc() -> [2]int,

	begin_frame: proc(),
	end_frame: proc(),
	clear: proc(color:Color),
	draw_rect: proc(pos, size: [2]f32, color: Color),
}

Color :: [4]u8
