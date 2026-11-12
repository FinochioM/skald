package scene

import "core:mem"
import "core:reflect"
import "core:strconv"
import "core:strings"

read_struct :: proc(text: string, ptr: rawptr, id: typeid, allocator := context.allocator) -> bool {
	text := text
	for raw in strings.split_lines_iterator(&text) {
		line := strings.trim_space(raw)
		if line == "" {
			continue
		}

		name, eq, value := strings.partition(line, " = ")
		if eq == "" {
			return false
		}

		field := reflect.struct_field_by_name(id, name)
		if field.type == nil {
			continue
		}

		fv := any{rawptr(uintptr(ptr) + field.offset), field.type.id}
		if !read_value(value, fv, allocator) {
			return false
		}
	}

	return true
}

read_value :: proc(s: string, v: any, allocator := context.allocator) -> bool {
	ti := reflect.type_info_base(type_info_of(v.id))

	#partial switch info in ti.variant {
	case reflect.Type_Info_Integer:
		n := strconv.parse_i128(s) or_return
		mem.copy(v.data, &n, ti.size)
	case reflect.Type_Info_Float:
		f := strconv.parse_f64(s) or_return
		switch ti.size {
		case 4: (^f32)(v.data)^ = f32(f)
		case 8: (^f64)(v.data)^ = f
		case:   return false
		}
	case reflect.Type_Info_Boolean:
		switch s {
		case "true":  (^bool)(v.data)^ = true
		case "false": (^bool)(v.data)^ = false
		case:         return false
		}
	case reflect.Type_Info_Enum:
		n := reflect.enum_from_name_any(v.id, s) or_return
		mem.copy(v.data, &n, ti.size)
	case reflect.Type_Info_String:
		str, allocated, ok := strconv.unquote_string(s, allocator)
		if !ok {
			return false
		}
		if !allocated {
			str = strings.clone(str, allocator)
		}
		(^string)(v.data)^ = str
	case reflect.Type_Info_Array:
		rest := s
		for i in 0 ..< info.count {
			part := strings.fields_iterator(&rest) or_return
			elem := any{rawptr(uintptr(v.data) + uintptr(i * info.elem_size)), info.elem.id}
			read_value(part, elem, allocator) or_return
		}
	case:
		return false
	}

	return true
}