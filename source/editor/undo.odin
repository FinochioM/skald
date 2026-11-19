package main

import "core:slice"

Edit :: struct {
	id: u64,
	before: []byte,
	after: []byte,
}

History :: struct {
	edits: [dynamic]Edit,
	done: int,
	pending: Edit,
}

touch :: proc(lvl: ^Editor_Level, id: u64, before: []byte) {
	if lvl.history.pending.before == nil {
		lvl.history.pending = {id = id, before = slice.clone(before, lvl.allocator)}
	}
}

settle :: proc(lvl: ^Editor_Level) {
	h := &lvl.history
	if h.pending.before == nil {
		return
	}
	defer h.pending = {}

	_, item := find_item(lvl, h.pending.id)
	if item == nil || slice.equal(item.data, h.pending.before) {
		return
	}

	resize(&h.edits, h.done)
	append(&h.edits, Edit{h.pending.id, h.pending.before, slice.clone(item.data, lvl.allocator)})
	h.done += 1
}

undo :: proc(lvl: ^Editor_Level) -> bool {
	h := &lvl.history
	if h.done == 0 {
		return false
	}
	h.done -= 1
	return apply(lvl, h.edits[h.done].id, h.edits[h.done].before)
}

redo :: proc(lvl: ^Editor_Level) -> bool {
	h := &lvl.history
	if h.done == len(h.edits) {
		return false
	}
	h.done += 1
	return apply(lvl, h.edits[h.done - 1].id, h.edits[h.done - 1].after)
}

@(private="file")
apply :: proc(lvl: ^Editor_Level, id: u64, data: []byte) -> bool {
	_, item := find_item(lvl, id)
	if item == nil {
		return false
	}
	copy(item.data, data)
	lvl.dirty = true
	return true
}