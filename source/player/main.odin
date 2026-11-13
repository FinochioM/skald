package main

import "core:fmt"
import "core:dynlib"
import "core:os"
import "core:time"

import "skald:backend_raylib"
import "skald:backend_nil"
import "skald:platform"

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

GAME_PATH :: #config(SKALD_GAME, "build/debug/games/boxes")

when ODIN_OS == .Windows {
	DLL_EXT :: ".dll"
} else when ODIN_OS == .Darwin {
	DLL_EXT :: ".dylib"
} else {
	DLL_EXT :: ".so"
}

Game_API :: struct {
	init: proc(pf: ^platform.Interface),
	step: proc(),
	shutdown: proc(),
	memory: proc() -> rawptr,
  	hot_reloaded: proc(mem: rawptr),

	__handle: dynlib.Library,

	mod_time: time.Time,
  	version: int,
}

platform_api: platform.Interface
game: Game_API
old_games: [dynamic]Game_API

main :: proc() {
  	if !init() {
  		return
  	}
  	for step() {}
  	shutdown()
}

init :: proc() -> bool {
  	platform_api = pf
  	platform_api.init(1280, 720, "skald")

  	ok: bool
  	if game, ok = load_game(0); !ok {
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

  	if t, err := os.modification_time_by_path(GAME_PATH + DLL_EXT); err == nil && t != game.mod_time {
  		reload_game()
  	}

  	game.step()
  	return true
}

shutdown :: proc() {
  	game.shutdown()
  	unload_game(game)
  	for old in old_games {
  		unload_game(old)
  	}
  	delete(old_games)
	platform_api.shutdown()
}

  load_game :: proc(version: int) -> (api: Game_API, ok: bool) {
  	src := GAME_PATH + DLL_EXT
  	mod_time, err := os.modification_time_by_path(src)
  	if err != nil {
  		fmt.eprintln("no game library at", src)
  		return
  	}

  	dst := fmt.tprintf("%s_%d%s", GAME_PATH, version, DLL_EXT)
  	if copy_err := os.copy_file(dst, src); copy_err != nil {
  		fmt.eprintln("could not copy", src, copy_err)
  		return
  	}

  	if _, loaded := dynlib.initialize_symbols(&api, dst, "game_"); !loaded {
  		fmt.eprintln("could not load", dst, dynlib.last_error())
  		return
  	}

  	api.mod_time = mod_time
  	api.version = version
  	return api, true
  }

  reload_game :: proc() {
  	new_game, ok := load_game(game.version + 1)
  	if !ok {
  		return
  	}

  	mem := game.memory()

  	append(&old_games, game)
  	game = new_game
  	game.hot_reloaded(mem)

  	fmt.println("reloaded game, version", game.version)
  }

  unload_game :: proc(api: Game_API) {
  	dynlib.unload_library(api.__handle)
  	os.remove(fmt.tprintf("%s_%d%s", GAME_PATH, api.version, DLL_EXT))
  }