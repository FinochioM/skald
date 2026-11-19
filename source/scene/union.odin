package scene

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:strings"

union_variant :: proc(data: rawptr, info: runtime.Type_Info_Union) -> ^runtime.Type_Info {
	i := union_index(data, info)
	return i < 0 ? nil : info.variants[i]
}

union_index :: proc(data: rawptr, info: runtime.Type_Info_Union) -> int {
	if len(info.variants) == 0 {
		return -1
	}
	tag := int(int_value(rawptr(uintptr(data) + info.tag_offset), info.tag_type.size, false))
	return info.no_nil ? tag : tag - 1
}

set_union_index :: proc(data: rawptr, info: runtime.Type_Info_Union, index: int, size: int) {
	if union_index(data, info) == index {
		return
	}
	mem.zero(data, size)
	tag := i128(info.no_nil ? index : index + 1)
	mem.copy(rawptr(uintptr(data) + info.tag_offset), &tag, info.tag_type.size)
}

@(private)
write_union_field :: proc(sb: ^strings.Builder, data: rawptr, info: runtime.Type_Info_Union, defaults: rawptr, indent, path: string) {
	v := union_variant(data, info)
	dv: ^runtime.Type_Info
	if defaults != nil {
		dv = union_variant(defaults, info)
		if v == dv && (v == nil || values_equal_ptr(data, defaults, v)) {
			return
		}
	}

	fmt.sbprintf(sb, "%s%s = %s\n", indent, path, v == nil ? "nil" : type_name(v))
	if v == nil {
		return
	}

	sub := defaults
	if dv != v {
		sub = raw_data(make([]byte, v.size, context.temp_allocator))
	}

	if _, is_struct := runtime.type_info_base(v).variant.(runtime.Type_Info_Struct); is_struct {
		write_struct_ptr(sb, data, v, sub, indent, fmt.tprintf("%s.", path))
	} else if !values_equal_ptr(data, sub, v) {
		fmt.sbprintf(sb, "%s%s.value = ", indent, path)
		write_value_ptr(sb, data, v)
		strings.write_byte(sb, '\n')
	}
}

@(private)
read_union :: proc(name: string, data: rawptr, info: runtime.Type_Info_Union, size: int) -> bool {
	if name == "nil" {
		if info.no_nil {
			return false
		}
		set_union_index(data, info, -1, size)
		return true
	}
	for v, i in info.variants {
		if type_name(v) == name {
			set_union_index(data, info, i, size)
			return true
		}
	}
	return false
}

@(private)
unions_equal :: proc(a, b: rawptr, info: runtime.Type_Info_Union) -> bool {
	v := union_variant(a, info)
	return v == union_variant(b, info) && (v == nil || values_equal_ptr(a, b, v))
}