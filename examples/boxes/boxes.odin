package boxes

import "core:fmt"
import "core:math/rand"
import "core:os"
import "core:strings"

import "skald:skald"

TICK_RATE :: 60
TICK_DT :: 1.0 / TICK_RATE

Box :: struct {
	pos: [2]f32,
  	prev_pos: [2]f32 `scene:"-"`,
	vel: [2]f32,
}

BOX_SIZE :: 32
BOX_COUNT :: 300
ORANGE :: skald.Color{255,161,0,255}

Action :: enum {
	Restart,
	Save,
}

BINDINGS := [Action]skald.Binding {
	.Restart = {.R},
	.Save = {.S},
}

LEVEL_DIR :: "examples/boxes"
LEVEL_PATH :: LEVEL_DIR + "/boxes.level"

State :: struct {
	pf: ^skald.Platform,
	level: skald.Level,
	boxes: skald.Collection(Box),
	accumulator: f64,
	input: skald.Input,
	fps: f64,
}

state: ^State

@(export)
game_init :: proc(pf: ^skald.Platform) {
	state = new(State)
	state.pf = pf

	load_level()
}

@(export)
game_step :: proc() {
	pf := state.pf

	skald.input_update(&state.input, pf.keys_down())

	dt := pf.frame_time()

	if dt > 0 {
		state.fps = state.fps * 0.95 + (1 / dt) * 0.05
	}

	state.accumulator += dt
	state.accumulator = min(state.accumulator, 0.25)

	for state.accumulator >= TICK_DT {
		if skald.action_pressed(state.input, BINDINGS, .Restart) {
			unload_level()
			load_level()
		}

  		if skald.action_pressed(state.input, BINDINGS, .Save) {
  			save_level()
  		}

		it := skald.make_iterator(&state.boxes)
		for box in skald.iterate(&it) {
			tick(box)
		}

		skald.input_consume(&state.input)

		state.accumulator -= TICK_DT
	}

	alpha := f32(state.accumulator / TICK_DT)

	pf.begin_frame()
	pf.clear({30, 30, 30, 255})

	it := skald.make_iterator(&state.boxes)
	for box in skald.iterate(&it) {
		draw_pos := box.prev_pos + (box.pos - box.prev_pos) * alpha
		pf.draw_rect(draw_pos, BOX_SIZE, ORANGE)
	}

	pf.draw_text(fmt.tprintf("%.0f fps", state.fps), {20, 20}, 20, {255, 255, 255, 255})

	pf.end_frame()

	free_all(context.temp_allocator)
}

@(export)
game_shutdown :: proc() {
	unload_level()
	free(state)
}

tick :: proc(b: ^Box) {
	b.prev_pos = b.pos
	b.pos += b.vel * TICK_DT
	
	screen := state.pf.screen_size()
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

random_boxes :: proc() {
	for _ in 0 ..< BOX_COUNT {
		pos := [2]f32{rand.float32_range(0, 1200), rand.float32_range(0, 650)}
		vel := [2]f32{rand.float32_range(-300, 300), rand.float32_range(-300, 300)}
		skald.add(&state.boxes, Box{pos = pos, prev_pos = pos, vel = vel})
	}
}

load_level :: proc() {
	skald.level_init(&state.level)
	state.boxes = skald.make_collection(Box, state.level.allocator)

	data, err := os.read_entire_file(LEVEL_PATH, context.temp_allocator)
	if err != nil {
		random_boxes()
		save_level()
		return
	}

	if !skald.load_collection(&state.boxes, string(data), Box{}, state.level.allocator) {
		fmt.eprintln("bad level file:", LEVEL_PATH)
	}

	it := skald.make_iterator(&state.boxes)
	for box in skald.iterate(&it) {
		box.prev_pos = box.pos
	}
}

save_level :: proc() {
	sb := strings.builder_make(context.temp_allocator)
	skald.save_collection(&sb, &state.boxes, Box{})

	_ = os.make_directory_all(LEVEL_DIR)
	if err := os.write_entire_file(LEVEL_PATH, strings.to_string(sb)); err != nil {
		fmt.eprintln("could not save", LEVEL_PATH, err)
	}
}

unload_level :: proc() {
	skald.level_destroy(&state.level)
	state.boxes = {}
}
