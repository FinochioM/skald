package main

import "core:fmt"
import "core:dynlib"
import "core:os"
import "core:mem"
import "core:time"
import "core:strings"
import "base:runtime"
import "core:path/filepath"

import "skald:backend_raylib"
import "skald:backend_nil"
import "skald:platform"
import "skald:reload"

BACKEND_NAME :: #config(SKALD_BACKEND, "raylib")

when BACKEND_NAME == "raylib" {
	pf :: backend_raylib.BACKEND
	_ :: backend_nil
} else when BACKEND_NAME == "nil" {
	pf :: backend_nil.BACKEND
	_ :: backend_raylib
} else {
	#panic("unknown SKALD_BACKEND: " + BACKEND_NAME)
}

GAME_DIR :: #config(SKALD_GAME_DIR, "build/debug/games")

Game_API :: struct {
	init: proc(pf: ^platform.Interface),
	step: proc(),
	shutdown: proc(),
	memory: proc() -> rawptr,
	memory_type: proc() -> ^runtime.Type_Info,
  	hot_reloaded: proc(mem: rawptr),

	__handle: dynlib.Library,
}

platform_api: platform.Interface
game: reload.Game(Game_API)
source_time: time.Time
build: os.Process
building: bool
game_source: string
game_path: string

main :: proc() {
  	if !init() {
  		return
  	}
  	for step() {}
  	shutdown()
}

init :: proc() -> bool {
	game_source = len(os.args) > 1 ? strings.trim_right(os.args[1], "/\\") : "boxes"
	if !os.is_dir(game_source) {
		game_source = strings.concatenate({"examples/", game_source})
	}
	game_path = strings.concatenate({GAME_DIR, "/", filepath.base(game_source)})

  	platform_api = pf
  	platform_api.init(1280, 720, "skald")
	source_time = newest_source_time()

	if !reload.open_game(&game, game_path) {
  		platform_api.shutdown()
  		return false
  	}

  	game.init(&platform_api)
  	return true
}

step :: proc() -> bool {
  	if platform_api.should_close() {
  		return false
  	}

	if reload.library_changed(&game) {
  		reload_game()
  	}

	watch_source()
  	
	game.step()
  	return true
}

shutdown :: proc() {
	if building {
		_, _ = os.process_wait(build)
	}

  	game.shutdown()
	reload.close_game(&game)
	platform_api.shutdown()
}

reload_game :: proc() {
  	next, mod_time, ok := reload.load_next(&game)
  	if !ok {
  		return
  	}

  	memory := game.memory()
  	old_type := game.memory_type()
  	new_type := next.memory_type()

  	if reload.layout_hash(new_type) != reload.layout_hash(old_type) {
  		moved, err := mem.alloc(new_type.size, new_type.align)
  		if err != nil {
  			fmt.eprintln("could not allocate the new state:", err)
  			reload.discard_next(&game, next)
  			return
  		}
  		reload.migrate(moved, new_type, memory, old_type)
  		free(memory)
  		memory = moved
  		fmt.println("state layout changed, moved it over by field name")
  	}

	reload.replace_game(&game, next, mod_time)
  	game.hot_reloaded(memory)

  	fmt.println("reloaded game, version", game.version)
}

newest_source_time :: proc() -> time.Time {
	files, err := os.read_all_directory_by_path(game_source, context.temp_allocator)
	if err != nil {
		return {}
	}

	newest: time.Time
	for f in files {
		if strings.has_suffix(f.name, ".odin") && time.diff(newest, f.modification_time) > 0 {
			newest = f.modification_time
		}
	}
	return newest
}

watch_source :: proc() {
	if building {
		state, err := os.process_wait(build, 0)
		if err != nil || !state.exited {
			return
		}

		building = false
		if !state.success {
			fmt.eprintln("game build failed, still running the old one")
		}
		return
	}

	t := newest_source_time()
	if t == source_time {
		return
	}
	source_time = t

	p, err := os.process_start({
		command = {"bash", "scripts/build_game.sh", game_source},
		stdout = os.stdout,
		stderr = os.stderr,
	})
	if err != nil {
		fmt.eprintln("could not start the game build:", err)
		return
	}

	build = p
	building = true
}