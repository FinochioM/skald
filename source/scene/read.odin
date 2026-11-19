package scene

import "core:mem"
import "core:reflect"
import "core:strconv"
import "core:strings"
import "base:runtime"

read_struct :: proc(text: string, ptr: rawptr, id: typeid, allocator := context.allocator) -> bool {
	return read_struct_ptr(text, ptr, type_info_of(id), allocator)
}

read_struct_ptr :: proc(text: string, ptr: rawptr, ti: ^runtime.Type_Info, allocator := context.allocator) -> bool {
	s, is_struct := runtime.type_info_base(ti).variant.(runtime.Type_Info_Struct)
	if !is_struct {
		return false
	}

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

		if !read_field(ptr, s, name, value, allocator) {
			return false
		}
	}

	return true
}

next_item :: proc(text: ^string) -> (type_name: string, id: u64, body: string, ok: bool) {
	header: string
	for header == "" {
		line := strings.split_lines_iterator(text) or_return
		header = strings.trim_space(line)
	}

	name, _, hex := strings.partition(header, " ")
	type_name = name
	id = strconv.parse_u64_of_base(hex, 16) or_return

	start := text^
	for len(text) > 0 && (text[0] == ' ' || text[0] == '\t' || text[0] == '\n' || text[0] == '\r') {
		_, _ = strings.split_lines_iterator(text)
	}
	body = start[:len(start) - len(text)]

	return type_name, id, body, true
}

read_value :: proc(s: string, v: any, allocator := context.allocator) -> bool {
	return read_value_ptr(s, v.data, type_info_of(v.id), allocator)
}

read_value_ptr :: proc(s: string, data: rawptr, ti: ^runtime.Type_Info, allocator := context.allocator) -> bool {
	base := runtime.type_info_base(ti)

	#partial switch info in base.variant {
	case runtime.Type_Info_Integer:
		n := strconv.parse_i128(s) or_return
		mem.copy(data, &n, base.size)
	case runtime.Type_Info_Float:
		f := strconv.parse_f64(s) or_return
		switch base.size {
		case 2: (^f16)(data)^ = f16(f)
		case 4: (^f32)(data)^ = f32(f)
		case 8: (^f64)(data)^ = f
		case:   return false
		}
	case runtime.Type_Info_Boolean:
		b: i128
		switch s {
		case "true":  b = 1
		case "false": b = 0
		case:         return false
		}
		mem.copy(data, &b, base.size)
	case runtime.Type_Info_Enum:
		for name, i in info.names {
			if name == s {
				n := i128(info.values[i])
				mem.copy(data, &n, base.size)
				return true
			}
		}
		return false
	case runtime.Type_Info_String:
		if info.is_cstring {
			return false
		}
		str, allocated, ok := strconv.unquote_string(s, allocator)
		if !ok {
			return false
		}
		if !allocated {
			str = strings.clone(str, allocator)
		}
		(^string)(data)^ = str
	case runtime.Type_Info_Array:
		rest := s
		for i in 0 ..< info.count {
			part := strings.fields_iterator(&rest) or_return
			elem := rawptr(uintptr(data) + uintptr(i * info.elem_size))
			read_value_ptr(part, elem, info.elem, allocator) or_return
		}
	case runtime.Type_Info_Union:
		return read_union(s, data, info, base.size)
	case runtime.Type_Info_Bit_Set:
		if !strings.has_prefix(s, "{") || !strings.has_suffix(s, "}") {
			return false
		}
		bits: i128
		rest := s[1:len(s) - 1]
		for part in strings.split_iterator(&rest, ",") {
			name := strings.trim_space(part)
			if name == "" {
				continue
			}
			b := (bit_set_elem_value(info, name) or_return) - info.lower
			if b < 0 || b >= i64(base.size * 8) {
				return false
			}
			bits |= 1 << uint(b)
		}
		mem.copy(data, &bits, base.size)
	case:
		return false
	}

	return true
}

field_index :: proc(s: runtime.Type_Info_Struct, name: string) -> int {
	for i in 0 ..< int(s.field_count) {
		if s.names[i] == name {
			return i
		}
	}
	for i in 0 ..< int(s.field_count) {
		if reflect.struct_tag_get(reflect.Struct_Tag(s.tags[i]), "was") == name {
			return i
		}
	}
	return -1
}

find_field :: proc(id: typeid, name: string) -> reflect.Struct_Field {
	if field := reflect.struct_field_by_name(id, name); field.type != nil {
		return field
	}
	for i in 0 ..< reflect.struct_field_count(id) {
		field := reflect.struct_field_at(id, i)
		if reflect.struct_tag_get(field.tag, "was") == name {
			return field
		}
	}
	return {}
}

@(private)
bit_set_elem_value :: proc(info: runtime.Type_Info_Bit_Set, name: string) -> (i64, bool) {
	if e, is_enum := runtime.type_info_base(info.elem).variant.(runtime.Type_Info_Enum); is_enum {
		for n, i in e.names {
			if n == name {
				return i64(e.values[i]), true
			}
		}
	}
	return strconv.parse_i64(name)
}

@(private)
read_field :: proc(ptr: rawptr, s: runtime.Type_Info_Struct, name, value: string, allocator: runtime.Allocator) -> bool {
	head, dot, tail := strings.partition(name, ".")
	i := field_index(s, head)
	if i < 0 {
		return true
	}

	field := rawptr(uintptr(ptr) + s.offsets[i])
	if dot == "" {
		return read_value_ptr(value, field, s.types[i], allocator)
	}

	u, is_union := runtime.type_info_base(s.types[i]).variant.(runtime.Type_Info_Union)
	if !is_union {
		return true
	}
	v := union_variant(field, u)
	if v == nil {
		return false
	}
	if inner, is_struct := runtime.type_info_base(v).variant.(runtime.Type_Info_Struct); is_struct {
		return read_field(field, inner, tail, value, allocator)
	}
	return tail == "value" && read_value_ptr(value, field, v, allocator)
}