package platformer

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:strings"

import "skald:skald"

TICK_RATE :: 60
TICK_DT :: 1.0 / TICK_RATE
GRAVITY :: 1800

LEVEL_DIR :: "examples/platformer"
LEVEL_PATH :: LEVEL_DIR + "/platformer.level"

Player :: struct {
	pos: [2]f32,
	size: [2]f32,
	speed: f32 `inspect:"range=50,600"`,
	jump: f32 `inspect:"range=100,1200"`,
	color: skald.Color `inspect:"color"`,

	vel: [2]f32 `scene:"-"`,
	prev_pos: [2]f32 `scene:"-"`,
	on_ground: bool `scene:"-"`,
}

Platform :: struct {
	pos: [2]f32,
	size: [2]f32,
	color: skald.Color `inspect:"color"`,
}

Action :: enum {
	Left,
	Right,
	Jump,
	Restart,
	Save,
}

BINDINGS := [Action]skald.Binding {
	.Left = {.Left, .A},
	.Right = {.Right, .D},
	.Jump = {.Space, .W, .Up},
	.Restart = {.R},
	.Save = {.S},
}

State :: struct {
	pf: ^skald.Platform,
	level: ^skald.Level,
	players: skald.Collection(Player),
	platforms: skald.Collection(Platform),
	accumulator: f64,
	input: skald.Input,
}

state: ^State

@(export)
game_init :: proc(pf: ^skald.Platform) {
	state = new(State)
	state.pf = pf
	state.level = new(skald.Level)
	load_level()
}

@(export)
game_step :: proc() {
	pf := state.pf
	skald.input_update(&state.input, pf.keys_down())

	state.accumulator = min(state.accumulator + pf.frame_time(), 0.25)
	for state.accumulator >= TICK_DT {
		if skald.action_pressed(state.input, BINDINGS, .Restart) {
			unload_level()
			load_level()
		}
		if skald.action_pressed(state.input, BINDINGS, .Save) {
			save_level()
		}

		it := skald.make_iterator(&state.players)
		for p in skald.iterate(&it) {
			tick_player(p)
		}

		skald.input_consume(&state.input)
		state.accumulator -= TICK_DT
	}

	alpha := f32(state.accumulator / TICK_DT)

	pf.begin_frame()
	pf.clear({24, 26, 34, 255})

	pit := skald.make_iterator(&state.platforms)
	for p in skald.iterate(&pit) {
		pf.draw_rect(p.pos, p.size, p.color)
	}

	it := skald.make_iterator(&state.players)
	for p in skald.iterate(&it) {
		pf.draw_rect(p.prev_pos + (p.pos - p.prev_pos) * alpha, p.size, p.color)
	}

	pf.end_frame()
	free_all(context.temp_allocator)
}

@(export)
game_shutdown :: proc() {
	unload_level()
	free(state.level)
	free(state)
}

@(export)
game_memory :: proc() -> rawptr {
	return state
}

@(export)
game_memory_type :: proc() -> ^runtime.Type_Info {
	return type_info_of(State)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	state = (^State)(mem)
}

tick_player :: proc(p: ^Player) {
	p.prev_pos = p.pos

	p.vel.x = 0
	if skald.action_down(state.input, BINDINGS, .Left) {
		p.vel.x -= p.speed
	}
	if skald.action_down(state.input, BINDINGS, .Right) {
		p.vel.x += p.speed
	}
	if p.on_ground && skald.action_pressed(state.input, BINDINGS, .Jump) {
		p.vel.y = -p.jump
	}
	p.vel.y += GRAVITY * TICK_DT

	p.pos.x += p.vel.x * TICK_DT
	push_out(p, 0)
	p.on_ground = false
	p.pos.y += p.vel.y * TICK_DT
	push_out(p, 1)
}

push_out :: proc(p: ^Player, axis: int) {
	it := skald.make_iterator(&state.platforms)
	for plat in skald.iterate(&it) {
		if !overlaps(p.pos, p.size, plat.pos, plat.size) {
			continue
		}

		if p.vel[axis] > 0 {
			p.pos[axis] = plat.pos[axis] - p.size[axis]
			if axis == 1 {
				p.on_ground = true
			}
		} else if p.vel[axis] < 0 {
			p.pos[axis] = plat.pos[axis] + plat.size[axis]
		}
		p.vel[axis] = 0
	}
}

overlaps :: proc(a_pos, a_size, b_pos, b_size: [2]f32) -> bool {
	return a_pos.x < b_pos.x + b_size.x && b_pos.x < a_pos.x + a_size.x &&
	       a_pos.y < b_pos.y + b_size.y && b_pos.y < a_pos.y + a_size.y
}

first_level :: proc() {
	skald.add(&state.players, Player{pos = {100, 400}, size = {28, 40}, speed = 280, jump = 700, color = {240, 200, 80, 255}})

	GROUND :: skald.Color{70, 80, 100, 255}
	skald.add(&state.platforms, Platform{pos = {0, 640}, size = {1280, 80}, color = GROUND})
	skald.add(&state.platforms, Platform{pos = {300, 520}, size = {200, 24}, color = GROUND})
	skald.add(&state.platforms, Platform{pos = {600, 420}, size = {200, 24}, color = GROUND})
	skald.add(&state.platforms, Platform{pos = {900, 320}, size = {200, 24}, color = GROUND})
}

load_level :: proc() {
	skald.level_init(state.level)
	state.players = skald.make_collection(Player, state.level.allocator)
	state.platforms = skald.make_collection(Platform, state.level.allocator)

	data, err := os.read_entire_file(LEVEL_PATH, context.temp_allocator)
	if err != nil {
		first_level()
		save_level()
		return
	}

	text := string(data)
	ok := skald.load_collection(&state.players, text, Player{}, state.level.allocator)
	ok &&= skald.load_collection(&state.platforms, text, Platform{}, state.level.allocator)
	if !ok {
		fmt.eprintln("bad level file:", LEVEL_PATH)
	}

	it := skald.make_iterator(&state.players)
	for p in skald.iterate(&it) {
		p.prev_pos = p.pos
	}
}

save_level :: proc() {
	sb := strings.builder_make(context.temp_allocator)
	skald.save_collection(&sb, &state.players, Player{})
	skald.save_collection(&sb, &state.platforms, Platform{})

	_ = os.make_directory_all(LEVEL_DIR)
	if err := os.write_entire_file(LEVEL_PATH, strings.to_string(sb)); err != nil {
		fmt.eprintln("could not save", LEVEL_PATH, err)
	}
}

unload_level :: proc() {
	skald.level_destroy(state.level)
	state.players = {}
	state.platforms = {}
}