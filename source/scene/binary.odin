package scene

import "core:encoding/endian"
import "core:reflect"
import "core:strings"

write_binary_struct :: proc(buf: ^[dynamic]byte, v: any) {
	for field in reflect.struct_fields_zipped(v.id) {
		if reflect.struct_tag_get(field.tag, "scene") == "-" {
			continue
		}

		append(buf, u8(len(field.name)))
		append(buf, field.name)

		start := len(buf)
		append_u32(buf, 0)
		write_binary_value(buf, reflect.struct_field_value(v, field))
		endian.put_u32(buf[start:], .Little, u32(len(buf) - start - 4))
	}
}

write_binary_value :: proc(buf: ^[dynamic]byte, v: any) {
	ti := reflect.type_info_base(type_info_of(v.id))

	#partial switch info in ti.variant {
	case reflect.Type_Info_Integer, reflect.Type_Info_Float, reflect.Type_Info_Boolean, reflect.Type_Info_Enum:
		append(buf, ..([^]byte)(v.data)[:ti.size])
	case reflect.Type_Info_String:
		s, _ := reflect.as_string(v)
		append_u32(buf, u32(len(s)))
		append(buf, s)
	case reflect.Type_Info_Array:
		for i in 0 ..< info.count {
			write_binary_value(buf, reflect.index(v, i))
		}
	case:
		// todo same list as write_value
	}
}

read_binary_struct :: proc(data: []byte, ptr: rawptr, id: typeid, allocator := context.allocator) -> bool {
	rest := data
	for len(rest) > 0 {
		name_len := int(rest[0])
		if len(rest) < 1 + name_len + 4 {
			return false
		}
		name := string(rest[1:][:name_len])
		rest = rest[1 + name_len:]

		size, _ := endian.get_u32(rest, .Little)
		rest = rest[4:]
		if len(rest) < int(size) {
			return false
		}
		value := rest[:size]
		rest = rest[size:]

		field := find_field(id, name)
		if field.type == nil || reflect.struct_tag_get(field.tag, "scene") == "-" {
			continue
		}

		scratch := make([]byte, field.type.size, context.temp_allocator)
		n, ok := read_binary_value(value, any{raw_data(scratch), field.type.id}, allocator)
		if !ok || n != len(value) {
			continue
		}
		copy(([^]byte)(uintptr(ptr) + field.offset)[:field.type.size], scratch)
	}

	return true
}

read_binary_value :: proc(b: []byte, v: any, allocator := context.allocator) -> (n: int, ok: bool) {
	ti := reflect.type_info_base(type_info_of(v.id))

	#partial switch info in ti.variant {
	case reflect.Type_Info_Integer, reflect.Type_Info_Float, reflect.Type_Info_Boolean, reflect.Type_Info_Enum:
		if len(b) < ti.size {
			return
		}
		copy(([^]byte)(v.data)[:ti.size], b)
		return ti.size, true
	case reflect.Type_Info_String:
		l := endian.get_u32(b, .Little) or_return
		if len(b) < 4 + int(l) {
			return
		}
		(^string)(v.data)^ = strings.clone(string(b[4:][:l]), allocator)
		return 4 + int(l), true
	case reflect.Type_Info_Array:
		for i in 0 ..< info.count {
			elem := any{rawptr(uintptr(v.data) + uintptr(i * info.elem_size)), info.elem.id}
			used := read_binary_value(b[n:], elem, allocator) or_return
			n += used
		}
		return n, true
	}

	return
}

@(private)
append_u32 :: proc(buf: ^[dynamic]byte, x: u32) {
	b: [4]byte
	endian.put_u32(b[:], .Little, x)
	append(buf, ..b[:])
}