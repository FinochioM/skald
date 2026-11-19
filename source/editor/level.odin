package main

import "core:mem"
import "core:os"
import "core:strings"
import "core:slice"

import "skald:scene"
import "skald:skald"

Item :: struct {
	id: u64,
	data: []byte,
}

Level_Collection :: struct {
	field: skald.Collection_Field,
	items: [dynamic]Item,
}

Editor_Level :: struct {
	using memory: skald.Level,
	path: string,
	collections: []Level_Collection,
	skipped: int,
	dirty: bool,
}

load_level :: proc(lvl: ^Editor_Level, path: string, fields: []skald.Collection_Field) -> bool {
	skald.level_init(&lvl.memory)
	lvl.path = strings.clone(path, lvl.allocator)

	lvl.collections = make([]Level_Collection, len(fields), lvl.allocator)
	for f, i in fields {
		lvl.collections[i] = {field = f, items = make([dynamic]Item, lvl.allocator)}
	}

	data, err := os.read_entire_file(path, context.temp_allocator)
	if err != nil {
		return false
	}

	text := string(data)
	for type_name, id, body in scene.next_item(&text) {
		c := find_level_collection(lvl, type_name)
		if c == nil {
			lvl.skipped += 1
			continue
		}

		bytes, alloc_err := mem.alloc_bytes(c.field.item.size, c.field.item.align, lvl.allocator)
		if alloc_err != nil || !scene.read_struct_ptr(body, raw_data(bytes), c.field.item, lvl.allocator) {
			return false
		}
		append(&c.items, Item{id, bytes})
	}

	return true
}

unload_level :: proc(lvl: ^Editor_Level) {
	skald.level_destroy(&lvl.memory)
	lvl^ = {}
}

find_level_collection :: proc(lvl: ^Editor_Level, type_name: string) -> ^Level_Collection {
	for &c in lvl.collections {
		if scene.type_name(c.field.item) == type_name {
			return &c
		}
	}
	return nil
}

find_item :: proc(lvl: ^Editor_Level, id: u64) -> (^Level_Collection, ^Item) {
	for &c in lvl.collections {
		for &item in c.items {
			if item.id == id {
				return &c, &item
			}
		}
	}
	return nil, nil
}

save_level :: proc(lvl: ^Editor_Level) -> bool {
	sb := strings.builder_make(context.temp_allocator)

	for c in lvl.collections {
		zero := make([]byte, c.field.item.size, context.temp_allocator)
		order := slice.clone(c.items[:], context.temp_allocator)
		slice.sort_by_key(order, proc(item: Item) -> u64 { return item.id })

		for item in order {
			scene.write_item_ptr(&sb, item.id, raw_data(item.data), c.field.item, raw_data(zero))
		}
	}

	if err := os.write_entire_file(lvl.path, strings.to_string(sb)); err != nil {
		return false
	}

	lvl.dirty = false
	return true
}