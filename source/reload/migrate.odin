package reload

import "base:runtime"
import "core:mem"
import "core:reflect"

migrate :: proc(dst: rawptr, dst_ti: ^runtime.Type_Info, src: rawptr, src_ti: ^runtime.Type_Info) {
	if layout_hash(dst_ti) == layout_hash(src_ti) {
		mem.copy(dst, src, dst_ti.size)
		return
	}

	d := runtime.type_info_base(dst_ti)
	s := runtime.type_info_base(src_ti)

	#partial switch dv in d.variant {
	case runtime.Type_Info_Struct:
		sv := s.variant.(runtime.Type_Info_Struct) or_break
		for i in 0 ..< int(dv.field_count) {
			j := find_field(sv, dv.names[i])
			if j < 0 {
				j = find_field(sv, reflect.struct_tag_get(reflect.Struct_Tag(dv.tags[i]), "was"))
			}
			if j < 0 {
				continue
			}
			migrate(
				rawptr(uintptr(dst) + dv.offsets[i]), dv.types[i],
				rawptr(uintptr(src) + sv.offsets[j]), sv.types[j],
			)
		}

	case runtime.Type_Info_Array:
		sv := s.variant.(runtime.Type_Info_Array) or_break
		for i in 0 ..< min(dv.count, sv.count) {
			migrate(
				rawptr(uintptr(dst) + uintptr(i * dv.elem_size)), dv.elem,
				rawptr(uintptr(src) + uintptr(i * sv.elem_size)), sv.elem,
			)
		}

	case runtime.Type_Info_Dynamic_Array:
		sv := s.variant.(runtime.Type_Info_Dynamic_Array) or_break
		old := (^runtime.Raw_Dynamic_Array)(src)
		new := (^runtime.Raw_Dynamic_Array)(dst)
		new.allocator = old.allocator
		if old.len == 0 {
			break
		}

		data, err := mem.alloc(old.len * dv.elem_size, dv.elem.align, old.allocator)
		if err != nil {
			break
		}
		new.data = data
		new.len = old.len
		new.cap = old.len

		for i in 0 ..< old.len {
			migrate(
				rawptr(uintptr(new.data) + uintptr(i * dv.elem_size)), dv.elem,
				rawptr(uintptr(old.data) + uintptr(i * sv.elem_size)), sv.elem,
			)
		}

		mem.free(old.data, old.allocator)
	case:

	}
}

@(private)
find_field :: proc(s: runtime.Type_Info_Struct, name: string) -> int {
	if name == "" {
		return -1
	}
	for i in 0 ..< int(s.field_count) {
		if s.names[i] == name {
			return i
		}
	}
	return -1
}