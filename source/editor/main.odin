package main

import "base:runtime"
import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:reflect"

import "skald:backend_nil"
import "skald:backend_raylib"
import "skald:platform"
import "skald:reload"
import "skald:skald"
import "skald:ui"
import "skald:scene"

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

Game_Types :: struct {
	memory_type: proc() -> ^runtime.Type_Info,

	__handle: dynlib.Library,
}

platform_api: platform.Interface
game: reload.Game(Game_Types)
game_path: string
collections: [dynamic]skald.Collection_Field
level: Editor_Level
level_ok: bool
selected: u64

ctx: ui.Context
font: platform.Font
left_split: f32 = 0.2
right_split: f32 = 0.7
bottom_split: f32 = 0.75

main :: proc() {
	if !init() {
		return
	}
	for step() {}
	shutdown()
}

init :: proc() -> bool {
	name := len(os.args) > 1 ? strings.trim_right(os.args[1], "/\\") : "boxes"
	game_path = strings.concatenate({GAME_DIR, "/", filepath.base(name)})

	platform_api = pf
	platform_api.init(1280, 720, "skald editor")

	if !reload.open_game(&game, game_path) {
		platform_api.shutdown()
		return false
	}
	collections = skald.find_collections(game.memory_type())
	level_path := len(os.args) > 2 ? os.args[2] : fmt.tprintf("examples/%s/%s.level", filepath.base(name), filepath.base(name))
	level_ok = load_level(&level, level_path, collections[:])

	scale := platform_api.dpi_scale()
	font = ui.load_default_font(&platform_api, ui.DEFAULT_THEME.font_size * scale)
	ui.init(&ctx, platform_api.measure_text, font, scale)
	return true
}

step :: proc() -> bool {
	if platform_api.should_close() {
		return false
	}

	ui.begin(&ctx, {
		mouse = platform_api.mouse_position(),
		down = platform_api.mouse_down(),
		text = platform_api.text_input(),
		keys = platform_api.keys_pressed(),
		wheel = platform_api.mouse_wheel(),
	})

	size := platform_api.screen_size()
	screen := ui.Rect{{0, 0}, {f32(size.x), f32(size.y)}}
	left, rest := ui.split(&ctx, "left split", screen, .Row, &left_split)
	center, right := ui.split(&ctx, "right split", rest, .Row, &right_split)
	view, bottom := ui.split(&ctx, "bottom split", center, .Column, &bottom_split)

	outliner(left)
	inspector(right)
	console(bottom)
	ui.push_rect(&ctx, view, {16, 16, 20, 255})

	ui.end(&ctx)

	platform_api.begin_frame()
	platform_api.clear({24, 24, 28, 255})
	ui.draw(&ctx, &platform_api)
	platform_api.end_frame()

	free_all(context.temp_allocator)
	return true
}

shutdown :: proc() {
	ui.destroy(&ctx)
	platform_api.unload_font(font)
	unload_level(&level)
	delete(collections)
	reload.close_game(&game)
	platform_api.shutdown()
}

outliner :: proc(r: ui.Rect) {
	ui.dock(&ctx, "outliner", r)

	for c in level.collections {
		name := scene.type_name(c.field.item)
		ui.label(&ctx, fmt.tprintf("%s  (%s, %d)", c.field.name, name, len(c.items)))

		for item in c.items {
			if ui.selectable(&ctx, fmt.tprintf("%s %016x", name, item.id), item.id == selected) {
				selected = item.id
			}
		}
	}
}

inspector :: proc(r: ui.Rect) {
	ui.dock(&ctx, "inspector", r)

	c, item := find_item(&level, selected)
	if item == nil {
		return
	}

	ti := c.field.item
	ui.label(&ctx, fmt.tprintf("%s %016x", scene.type_name(ti), item.id))

	s := runtime.type_info_base(ti).variant.(runtime.Type_Info_Struct)
	for i in 0 ..< int(s.field_count) {
		if reflect.struct_tag_get(reflect.Struct_Tag(s.tags[i]), "scene") == "-" {
			continue
		}

		ui.row(&ctx)
		ui.label(&ctx, s.names[i])
		if edit_value(s.names[i], rawptr(uintptr(raw_data(item.data)) + s.offsets[i]), s.types[i]) {
			level.dirty = true
		}
	}
}

console :: proc(r: ui.Rect) {
	ui.dock(&ctx, "console", r)
	ui.label(&ctx, fmt.tprintf("opened %s%s, %d collections", game_path, reload.DLL_EXT, len(collections)))

	if level.dirty {
		ui.label(&ctx, fmt.tprintf("%s modified", level.path))
	}

	if !level_ok {
		ui.label(&ctx, fmt.tprintf("could not read %s", level.path))
	} else if level.skipped > 0 {
		ui.label(&ctx, fmt.tprintf("%s: skipped %d items with no collection", level.path, level.skipped))
	}
}

type_name :: proc(ti: ^runtime.Type_Info) -> string {
	if named, ok := ti.variant.(runtime.Type_Info_Named); ok {
		return named.name
	}
	return "?"
}