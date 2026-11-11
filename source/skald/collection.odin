package skald

Handle :: struct($T: typeid) {
	index: u32,
	gen: u32,
}

Collection :: struct($T: typeid) {
	slots: [dynamic]Slot(T),
}

@(private)
Slot :: struct($T: typeid) {
	value: T,
	gen: u32,
}

make_collection :: proc($T: typeid, allocator := context.allocator) -> Collection(T) {
	return {slots = make([dynamic]Slot(T), allocator)}
}

destroy_collection :: proc(c: ^Collection($T)) {
	delete(c.slots)
}

add :: proc(c: ^Collection($T), value: T) -> Handle(T) {
	append(&c.slots, Slot(T){value = value, gen = 1})
	// todo reuse removed slots
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
