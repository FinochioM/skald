package skald

import "core:fmt"
import "core:slice"
import "core:strings"

import "skald:scene"

save_collection :: proc(sb: ^strings.Builder, c: ^Collection($T), defaults: T) {
	Entry :: struct {
		id: u64,
		index: u32,
	}

	order := make([dynamic]Entry, context.temp_allocator)
	for slot, i in c.slots {
		if slot.alive {
			append(&order, Entry{slot.id, u32(i)})
		}
	}
	slice.sort_by_key(order[:], proc(e: Entry) -> u64 { return e.id })

	for e in order {
		scene.write_item(sb, e.id, c.slots[e.index].value, defaults)
	}
}

load_collection :: proc(c: ^Collection($T), text: string, defaults: T, allocator := context.allocator) -> bool {
	name := fmt.tprint(typeid_of(T))

	rest := text
	for type_name, id, body in scene.next_item(&rest) {
		if type_name != name {
			continue
		}

		value := defaults
		scene.read_struct(body, &value, T, allocator) or_return
		add(c, value, id)
	}

	return true
}