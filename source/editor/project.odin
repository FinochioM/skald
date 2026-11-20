package main

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

import "skald:reload"
import "skald:skald"
import "skald:ui"

PROJECTS_DIR :: "examples"

project: string

find_projects :: proc(allocator := context.temp_allocator) -> []string {
	names := make([dynamic]string, allocator)

	dirs, err := os.read_all_directory_by_path(PROJECTS_DIR, context.temp_allocator)
	if err != nil {
		return names[:]
	}

	for d in dirs {
		if d.type != .Directory {
			continue
		}
		files, _ := os.read_all_directory_by_path(d.fullpath, context.temp_allocator)
		for f in files {
			if strings.has_suffix(f.name, ".odin") {
				append(&names, strings.clone(d.name, allocator))
				break
			}
		}
	}

	slice.sort(names[:])
	return names[:]
}

open_project :: proc(name: string) -> bool {
	game_path = strings.concatenate({GAME_DIR, "/", name})
	if !reload.open_game(&game, game_path) {
		status = fmt.bprintf(status_buf[:], "%s isn't built: bash scripts/build_game.sh %s", name, name)
		delete(game_path)
		return false
	}
	if game.memory_type == nil {
		status = fmt.bprintf(status_buf[:], "%s doesn't export game_memory_type", name)
		reload.close_game(&game)
		delete(game_path)
		return false
	}

	project = strings.clone(name)
	collections = skald.find_collections(game.memory_type())
	level_ok = load_level(&level, fmt.tprintf("%s/%s/%s.level", PROJECTS_DIR, name, name), collections[:])
	status = ""
	return true
}

close_project :: proc() {
	if project == "" {
		return
	}
	unload_level(&level)
	delete(collections)
	reload.close_game(&game)
	delete(game_path)
	delete(project)

	project, game_path, collections, selected = "", "", nil, 0
	game = {}
}

project_manager :: proc(screen: ui.Rect) {
	w := min(screen.size.x, 480)
	ui.dock(&ctx, "projects", {screen.pos + {(screen.size.x - w) / 2, 0}, {w, screen.size.y}})

	for name in find_projects() {
		built := os.exists(fmt.tprintf("%s/%s%s", GAME_DIR, name, reload.DLL_EXT))
		if ui.button(&ctx, built ? name : fmt.tprintf("%s (not built)", name)) {
			open_project(name)
		}
	}

	if status != "" {
		ui.label(&ctx, status)
	}
}