package skald

Handle :: struct($T: typeid) {
	index: u32,
	gen: u32,
}

Collection :: struct($T: typeid) {
	slots: [dynamic]Slot(T),

	free: [dynamic]u32,
}

@(private)
Slot :: struct($T: typeid) {
	value: T,
	gen: u32,
	alive: bool,
}

make_collection :: proc($T: typeid, allocator := context.allocator) -> Collection(T) {
	return {slots = make([dynamic]Slot(T), allocator),
		free = make([dynamic]u32, allocator),
	}
}

destroy_collection :: proc(c: ^Collection($T)) {
	delete(c.slots)
	delete(c.free)
}

add :: proc(c: ^Collection($T), value: T) -> Handle(T) {
	if len (c.free) > 0 {
		index := pop(&c.free)
		slot := &c.slots[index]
		slot.value = value
		slot.alive = true

		return {index = index, gen = slot.gen}
	}
	append(&c.slots, Slot(T){value = value, gen = 1, alive = true})
	return {index = u32(len(c.slots) - 1), gen = 1}
}	

get :: proc(c: ^Collection($T), h: Handle(T)) -> ^T {
	if int(h.index) >= len(c.slots) {
		return nil
	}

	slot := &c.slots[h.index]
	if slot.gen != h.gen {
		return nil
	}

	return &slot.value
}

remove :: proc(c: ^Collection($T), h: Handle(T)) -> bool {
	if get(c, h) == nil {
		return false
	}

	slot := &c.slots[h.index]
	slot.value = {}
	slot.alive = false

	slot.gen += 1
	if slot.gen == 0 {
		slot.gen = 1
	}

	append(&c.free, h.index)

	return true
}

count :: proc(c: ^Collection($T)) -> int {
	return len(c.slots) - len(c.free)
}

Iterator :: struct($T: typeid) {
	c: ^Collection(T),
	index: int,
}

make_iterator :: proc(c: ^Collection($T)) -> Iterator(T) {
	return {c=c}
}

iterate :: proc(it: ^Iterator($T)) -> (value: ^T, h: Handle(T), ok: bool) {
	for it.index < len(it.c.slots) {
		i := it.index
		it.index += 1

		slot := &it.c.slots[i]
		if slot.alive {
			return &slot.value, {index = u32(i), gen = slot.gen}, true
		}
	}

	return
}
