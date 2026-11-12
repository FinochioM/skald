package scene

import "core:fmt"
import "core:reflect"
import "core:strings"
import "core:mem"

write_struct :: proc(sb: ^strings.Builder, v: any, defaults: any = nil) {
	for field in reflect.struct_fields_zipped(v.id) {
		value := reflect.struct_field_value(v, field)
		if defaults != nil && values_equal(value, reflect.struct_field_value(defaults, field)) {
			continue
		}

		fmt.sbprintf(sb, "%s = ", field.name)
		write_value(sb, value)
		strings.write_byte(sb, '\n')
	}
}

write_value :: proc(sb: ^strings.Builder, v: any) {
	ti := reflect.type_info_base(type_info_of(v.id))

	#partial switch info in ti.variant {
	case reflect.Type_Info_Integer, reflect.Type_Info_Float, reflect.Type_Info_Boolean:
		fmt.sbprint(sb, v)
	case reflect.Type_Info_Enum:
		name, _ := reflect.enum_name_from_value_any(v)
		strings.write_string(sb, name)
	case reflect.Type_Info_String:
		s, _ := reflect.as_string(v)
		strings.write_quoted_string(sb, s)
	case reflect.Type_Info_Array:
		for i in 0 ..< info.count {
			if i > 0 {
				strings.write_byte(sb, ' ')
			}
			write_value(sb, reflect.index(v, i))
		}
	case:
		// todo slices, unions, bit_sets, nested structs
		fmt.sbprintf(sb, "?%v", v.id)
	}
}

values_equal :: proc(a, b: any) -> bool {
	ti := reflect.type_info_base(type_info_of(a.id))

	#partial switch info in ti.variant {
	case reflect.Type_Info_String:
		sa, _ := reflect.as_string(a)
		sb, _ := reflect.as_string(b)
		return sa == sb
	case reflect.Type_Info_Array:
		for i in 0 ..< info.count {
			if !values_equal(reflect.index(a, i), reflect.index(b, i)) {
				return false
			}
		}
		return true
	}

	return mem.compare_ptrs(a.data, b.data, ti.size) == 0
}