package main

import "core:fmt"
import "core:dynlib"

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

	__handle: dynlib.Library,
}

platform_api: platform.Interface
game: Game_API

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

  	path := GAME_PATH + DLL_EXT
  	if _, ok := dynlib.initialize_symbols(&game, path, "game_"); !ok {
  		fmt.eprintln("could not load", path, dynlib.last_error())
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

  	game.step()
  	return true
}

shutdown :: proc() {
  	game.shutdown()
  	dynlib.unload_library(game.__handle)
	platform_api.shutdown()
}