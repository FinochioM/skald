package skald

import "core:mem"

Level :: struct {
	arena: mem.Dynamic_Arena,
	allocator: mem.Allocator,
}

level_init :: proc(lvl: ^Level, backing := context.allocator) {
	mem.dynamic_arena_init(&lvl.arena, backing, backing)
	lvl.allocator = mem.dynamic_arena_allocator(&lvl.arena)
}

level_destroy :: proc(lvl: ^Level) {
	mem.dynamic_arena_destroy(&lvl.arena)
	lvl^ = {}
}
