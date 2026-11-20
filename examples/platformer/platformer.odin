package platformer

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:math"

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

Coin :: struct {
	pos: [2]f32,
	value: int `inspect:"range=1,100"`,

	taken: bool `scene:"-"`,
}

Enemy_Kind :: enum {
	Slime,
	Bat,
}

Enemy_Flag :: enum {
	Deadly,
	Bouncy,
}

Patrol :: struct {
	left, right: f32,
	speed: f32 `inspect:"range=0,400"`,
}

Hover :: struct {
	height: f32 `inspect:"range=0,300"`,
	period: f32 `inspect:"range=0.2,10"`,
}

Enemy :: struct {
	name: string,
	pos: [2]f32,
	kind: Enemy_Kind,
	flags: bit_set[Enemy_Flag],
	move: union {
		Patrol,
		Hover,
	},

	start: [2]f32 `scene:"-"`,
	prev_pos: [2]f32 `scene:"-"`,
	dir: f32 `scene:"-"`,
	time: f32 `scene:"-"`,
}

COIN_SIZE :: 16
ENEMY_SIZE :: 28

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
	coins: skald.Collection(Coin),
	enemies: skald.Collection(Enemy),
	accumulator: f64,
	input: skald.Input,
	score: int,
	dead: bool,
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

        eit := skald.make_iterator(&state.enemies)
        for e in skald.iterate(&eit) {
            tick_enemy(e)
        }

		it := skald.make_iterator(&state.players)
		for p in skald.iterate(&it) {
			tick_player(p)
            touch_things(p)
		}

        if state.dead {
            unload_level()
            load_level()
        }

		skald.input_consume(&state.input)
		state.accumulator -= TICK_DT
	}

	alpha := f32(state.accumulator / TICK_DT)

	pf.begin_frame()
	pf.clear({24, 26, 34, 255})

	cit := skald.make_iterator(&state.coins)
	for c in skald.iterate(&cit) {
		if !c.taken {
			pf.draw_rect(c.pos, COIN_SIZE, {250, 210, 60, 255})
		}
	}

	eit := skald.make_iterator(&state.enemies)
	for e in skald.iterate(&eit) {
		color := e.kind == .Slime ? skald.Color{90, 200, 110, 255} : skald.Color{160, 100, 220, 255}
		pf.draw_rect(e.prev_pos + (e.pos - e.prev_pos) * alpha, ENEMY_SIZE, color)
	}

	pit := skald.make_iterator(&state.platforms)
	for p in skald.iterate(&pit) {
		pf.draw_rect(p.pos, p.size, p.color)
	}

	it := skald.make_iterator(&state.players)
	for p in skald.iterate(&it) {
		pf.draw_rect(p.prev_pos + (p.pos - p.prev_pos) * alpha, p.size, p.color)
	}

	pf.draw_text(skald.DEFAULT_FONT, fmt.tprintf("score %d", state.score), {20, 20}, 24, {255, 255, 255, 255})

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

	skald.add(&state.coins, Coin{pos = {390, 480}, value = 1})
	skald.add(&state.coins, Coin{pos = {690, 380}, value = 1})
	skald.add(&state.coins, Coin{pos = {990, 280}, value = 5})

	skald.add(&state.enemies, Enemy{
		name = "walker", pos = {600, 612}, kind = .Slime, flags = {.Deadly, .Bouncy},
		move = Patrol{left = 500, right = 860, speed = 90},
	})
	skald.add(&state.enemies, Enemy{
		name = "flier", pos = {1150, 200}, kind = .Bat, flags = {.Deadly},
		move = Hover{height = 60, period = 2},
	})
}

load_level :: proc() {
	skald.level_init(state.level)
	state.players = skald.make_collection(Player, state.level.allocator)
	state.platforms = skald.make_collection(Platform, state.level.allocator)
	state.coins = skald.make_collection(Coin, state.level.allocator)
	state.enemies = skald.make_collection(Enemy, state.level.allocator)
	state.score = 0
	state.dead = false

	data, err := os.read_entire_file(LEVEL_PATH, context.temp_allocator)
	if err != nil {
		first_level()
		save_level()
	} else {
		text := string(data)
		a := state.level.allocator
		ok := skald.load_collection(&state.players, text, Player{}, a)
		ok &&= skald.load_collection(&state.platforms, text, Platform{}, a)
		ok &&= skald.load_collection(&state.coins, text, Coin{}, a)
		ok &&= skald.load_collection(&state.enemies, text, Enemy{}, a)
		if !ok {
			fmt.eprintln("bad level file:", LEVEL_PATH)
		}
	}

	it := skald.make_iterator(&state.players)
	for p in skald.iterate(&it) {
		p.prev_pos = p.pos
	}
	eit := skald.make_iterator(&state.enemies)
	for e in skald.iterate(&eit) {
		e.start, e.prev_pos = e.pos, e.pos
	}
}

save_level :: proc() {
	sb := strings.builder_make(context.temp_allocator)
	skald.save_collection(&sb, &state.players, Player{})
	skald.save_collection(&sb, &state.platforms, Platform{})

	skald.save_collection(&sb, &state.coins, Coin{})
	skald.save_collection(&sb, &state.enemies, Enemy{})

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

tick_enemy :: proc(e: ^Enemy) {
	e.prev_pos = e.pos
	e.time += TICK_DT

	switch m in e.move {
	case Patrol:
		if e.dir == 0 {
			e.dir = 1
		}
		e.pos.x += e.dir * m.speed * TICK_DT
		if e.pos.x > m.right {
			e.pos.x, e.dir = m.right, -1
		} else if e.pos.x < m.left {
			e.pos.x, e.dir = m.left, 1
		}
	case Hover:
		if m.period > 0 {
			e.pos.y = e.start.y + math.sin(e.time * math.TAU / m.period) * m.height
		}
	}
}

touch_things :: proc(p: ^Player) {
	cit := skald.make_iterator(&state.coins)
	for c in skald.iterate(&cit) {
		if !c.taken && overlaps(p.pos, p.size, c.pos, COIN_SIZE) {
			c.taken = true
			state.score += c.value
		}
	}

	eit := skald.make_iterator(&state.enemies)
	for e in skald.iterate(&eit) {
		if !overlaps(p.pos, p.size, e.pos, ENEMY_SIZE) {
			continue
		}

		from_above := p.vel.y > 0 && p.prev_pos.y + p.size.y <= e.prev_pos.y
		if .Bouncy in e.flags && from_above {
			p.pos.y = e.pos.y - p.size.y
			p.vel.y = -p.jump
		} else if .Deadly in e.flags {
			state.dead = true
		}
	}
}