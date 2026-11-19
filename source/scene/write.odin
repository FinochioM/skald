package scene

import "core:fmt"
import "core:reflect"
import "core:strings"
import "core:mem"
import "base:runtime"

write_struct :: proc(sb: ^strings.Builder, v: any, defaults: any = nil, indent := "") {
	write_struct_ptr(sb, v.data, type_info_of(v.id), defaults.data, indent)
}

write_struct_ptr :: proc(sb: ^strings.Builder, data: rawptr, ti: ^runtime.Type_Info, defaults: rawptr = nil, indent := "", prefix := "") {
	s, ok := runtime.type_info_base(ti).variant.(runtime.Type_Info_Struct)
	if !ok {
		return
	}

	for i in 0 ..< int(s.field_count) {
		if reflect.struct_tag_get(reflect.Struct_Tag(s.tags[i]), "scene") == "-" {
			continue
		}

		field := rawptr(uintptr(data) + s.offsets[i])
		if defaults != nil && values_equal_ptr(field, rawptr(uintptr(defaults) + s.offsets[i]), s.types[i]) {
			continue
		}
		
		if u, is_union := runtime.type_info_base(s.types[i]).variant.(runtime.Type_Info_Union); is_union {
			def := defaults == nil ? nil : rawptr(uintptr(defaults) + s.offsets[i])
			write_union_field(sb, field, u, def, indent, fmt.tprintf("%s%s", prefix, s.names[i]))
			continue
		}

		fmt.sbprintf(sb, "%s%s%s = ", indent, prefix, s.names[i])
		write_value_ptr(sb, field, s.types[i])
		strings.write_byte(sb, '\n')
	}
}

write_item :: proc(sb: ^strings.Builder, id: u64, v: any, defaults: any = nil) {
	write_item_ptr(sb, id, v.data, type_info_of(v.id), defaults.data)
}

write_item_ptr :: proc(sb: ^strings.Builder, id: u64, data: rawptr, ti: ^runtime.Type_Info, defaults: rawptr = nil) {
	fmt.sbprintf(sb, "%s %016x\n", type_name(ti), id)
	write_struct_ptr(sb, data, ti, defaults, "  ")
}

type_name :: proc(ti: ^runtime.Type_Info) -> string {
	#partial switch info in ti.variant {
	case runtime.Type_Info_Named:
		return info.name
	case runtime.Type_Info_Integer:
		return fmt.tprintf("%s%d", info.signed ? "i" : "u", ti.size * 8)
	case runtime.Type_Info_Float:
		return fmt.tprintf("f%d", ti.size * 8)
	case runtime.Type_Info_Boolean:
		return "bool"
	case runtime.Type_Info_String:
		return "string"
	}
	return "?"
}

write_value :: proc(sb: ^strings.Builder, v: any) {
	write_value_ptr(sb, v.data, type_info_of(v.id))
}

write_value_ptr :: proc(sb: ^strings.Builder, data: rawptr, ti: ^runtime.Type_Info) {
	base := runtime.type_info_base(ti)

	#partial switch info in base.variant {
	case runtime.Type_Info_Integer:
		fmt.sbprint(sb, int_value(data, base.size, info.signed))
	case runtime.Type_Info_Float:
		switch base.size {
		case 2: fmt.sbprint(sb, (^f16)(data)^)
		case 4: fmt.sbprint(sb, (^f32)(data)^)
		case 8: fmt.sbprint(sb, (^f64)(data)^)
		}
	case runtime.Type_Info_Boolean:
		fmt.sbprint(sb, int_value(data, base.size, false) != 0)
	case runtime.Type_Info_Enum:
		if name, ok := enum_name(data, info, base.size); ok {
			strings.write_string(sb, name)
		}
	case runtime.Type_Info_String:
		if !info.is_cstring {
			strings.write_quoted_string(sb, (^string)(data)^)
		}
	case runtime.Type_Info_Array:
		for i in 0 ..< info.count {
			if i > 0 {
				strings.write_byte(sb, ' ')
			}
			write_value_ptr(sb, rawptr(uintptr(data) + uintptr(i * info.elem_size)), info.elem)
		}
	case runtime.Type_Info_Bit_Set:
		bits := int_value(data, base.size, false)
		strings.write_byte(sb, '{')
		first := true
		for b in 0 ..< base.size * 8 {
			if (bits >> uint(b)) & 1 == 0 {
				continue
			}
			if !first {
				strings.write_string(sb, ", ")
			}
			first = false
			name, _ := bit_set_elem_name(info, info.lower + i64(b))
			strings.write_string(sb, name)
		}
		strings.write_byte(sb, '}')
	case:
		fmt.sbprintf(sb, "?%s", type_name(ti))
	}
}

values_equal :: proc(a, b: any) -> bool {
	return values_equal_ptr(a.data, b.data, type_info_of(a.id))
}

values_equal_ptr :: proc(a, b: rawptr, ti: ^runtime.Type_Info) -> bool {
	base := runtime.type_info_base(ti)

	#partial switch info in base.variant {
	case runtime.Type_Info_String:
		if !info.is_cstring {
			return (^string)(a)^ == (^string)(b)^
		}
	case runtime.Type_Info_Union:
		return unions_equal(a, b, info)
	case runtime.Type_Info_Array:
		for i in 0 ..< info.count {
			offset := uintptr(i * info.elem_size)
			if !values_equal_ptr(rawptr(uintptr(a) + offset), rawptr(uintptr(b) + offset), info.elem) {
				return false
			}
		}
		return true
	}

	return mem.compare_ptrs(a, b, base.size) == 0
}

int_value :: proc(data: rawptr, size: int, signed: bool) -> i128 {
	switch size {
	case 1:  return signed ? i128((^i8)(data)^) : i128((^u8)(data)^)
	case 2:  return signed ? i128((^i16)(data)^) : i128((^u16)(data)^)
	case 4:  return signed ? i128((^i32)(data)^) : i128((^u32)(data)^)
	case 8:  return signed ? i128((^i64)(data)^) : i128((^u64)(data)^)
	case 16: return (^i128)(data)^
	}
	return 0
}

@(private)
enum_name :: proc(data: rawptr, info: runtime.Type_Info_Enum, size: int) -> (string, bool) {
	signed := false
	if i, ok := runtime.type_info_base(info.base).variant.(runtime.Type_Info_Integer); ok {
		signed = i.signed
	}

	v := runtime.Type_Info_Enum_Value(int_value(data, size, signed))
	for value, i in info.values {
		if value == v {
			return info.names[i], true
		}
	}
	return "", false
}

bit_set_elem_name :: proc(info: runtime.Type_Info_Bit_Set, v: i64) -> (name: string, ok: bool) {
	if e, is_enum := runtime.type_info_base(info.elem).variant.(runtime.Type_Info_Enum); is_enum {
		for value, i in e.values {
			if i64(value) == v {
				return e.names[i], true
			}
		}
		return fmt.tprint(v), false
	}
	return fmt.tprint(v), true
}