package reload

import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:time"

when ODIN_OS == .Windows {
	DLL_EXT :: ".dll"
} else when ODIN_OS == .Darwin {
	DLL_EXT :: ".dylib"
} else {
	DLL_EXT :: ".so"
}

Game :: struct($API: typeid) {
	using api: API,
	path: string,
	mod_time: time.Time,
	version: int,
	old: [dynamic]dynlib.Library,
}

open_game :: proc(g: ^Game($API), path: string) -> bool {
	g.path = path
	api, mod_time, ok := load_copy(API, path, 0)
	if !ok {
		return false
	}

	g.api = api
	g.mod_time = mod_time
	return true
}

library_changed :: proc(g: ^Game($API)) -> bool {
	t, err := os.modification_time_by_path(fmt.tprintf("%s%s", g.path, DLL_EXT))
	return err == nil && t != g.mod_time
}

load_next :: proc(g: ^Game($API)) -> (next: API, mod_time: time.Time, ok: bool) {
	return load_copy(API, g.path, g.version + 1)
}

replace_game :: proc(g: ^Game($API), next: API, mod_time: time.Time) {
	append(&g.old, g.api.__handle)
	g.api = next
	g.mod_time = mod_time
	g.version += 1
}

discard_next :: proc(g: ^Game($API), next: API) {
	dynlib.unload_library(next.__handle)
	remove_copy(g.path, g.version + 1)
}

close_game :: proc(g: ^Game($API)) {
	dynlib.unload_library(g.api.__handle)
	unload_all(&g.old)

	for v in 0 ..= g.version {
		remove_copy(g.path, v)
	}
}

@(private)
load_copy :: proc($API: typeid, path: string, version: int) -> (api: API, mod_time: time.Time, ok: bool) {
	src := fmt.tprintf("%s%s", path, DLL_EXT)
	t, err := os.modification_time_by_path(src)
	if err != nil {
		fmt.eprintln("no game library at", src)
		return
	}

	dst := copy_path(path, version)
	if copy_err := os.copy_file(dst, src); copy_err != nil {
		fmt.eprintln("could not copy", src, copy_err)
		return
	}

	if _, loaded := dynlib.initialize_symbols(&api, dst, "game_"); !loaded {
		fmt.eprintln("could not load", dst, dynlib.last_error())
		remove_copy(path, version)
		return
	}

	return api, t, true
}

@(private)
copy_path :: proc(path: string, version: int) -> string {
	return fmt.tprintf("%s_%d%s", path, version, DLL_EXT)
}

@(private)
remove_copy :: proc(path: string, version: int) {
	os.remove(copy_path(path, version))
}

@(private)
unload_all :: proc(libs: ^[dynamic]dynlib.Library) {
	for lib in libs {
		dynlib.unload_library(lib)
	}
	delete(libs^)
}