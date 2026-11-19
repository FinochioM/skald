package main

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:strings"

import "skald:scene"
import "skald:ui"

edit_value :: proc(label: string, data: rawptr, ti: ^runtime.Type_Info) -> (changed: bool) {
	base := runtime.type_info_base(ti)

	#partial switch info in base.variant {
	case runtime.Type_Info_Integer:
		v := f64(scene.int_value(data, base.size, info.signed))
		if ui.drag(&ctx, label, &v, 1, "%.0f") {
			n := i128(math.round(v))
			if !info.signed {
				n = max(n, 0)
			}
			mem.copy(data, &n, base.size)
			changed = true
		}
	case runtime.Type_Info_Float:
		v := float_value(data, base.size)
		if ui.drag(&ctx, label, &v, 1, "%.3f") {
			switch base.size {
			case 2: (^f16)(data)^ = f16(v)
			case 4: (^f32)(data)^ = f32(v)
			case 8: (^f64)(data)^ = v
			}
			changed = true
		}
	case runtime.Type_Info_Boolean:
		b := scene.int_value(data, base.size, false) != 0
		if ui.checkbox(&ctx, label, &b) {
			n := i128(b)
			mem.copy(data, &n, base.size)
			changed = true
		}
	case runtime.Type_Info_Array:
		ui.push_id(&ctx, label)
		defer ui.pop_id(&ctx)
		for i in 0 ..< info.count {
			elem := rawptr(uintptr(data) + uintptr(i * info.elem_size))
			changed |= edit_value(fmt.tprint(i), elem, info.elem)
		}
	case runtime.Type_Info_Enum:
		changed = edit_enum(label, data, info, base.size)
	case runtime.Type_Info_String:
		if info.is_cstring {
			ui.label(&ctx, "cstring")
			break
		}
		text := strings.builder_make(context.temp_allocator)
		strings.write_string(&text, (^string)(data)^)
		if ui.text_field(&ctx, label, &text) {
			(^string)(data)^ = strings.clone(strings.to_string(text), level.allocator)
			changed = true
		}
	case:
		// todo slices, unions, bit_sets, nested structs
		text := strings.builder_make(context.temp_allocator)
		scene.write_value_ptr(&text, data, ti)
		ui.label(&ctx, strings.to_string(text))
	}

	return
}

@(private="file")
edit_enum :: proc(label: string, data: rawptr, info: runtime.Type_Info_Enum, size: int) -> bool {
	if len(info.values) == 0 {
		return false
	}

	signed := false
	if i, ok := runtime.type_info_base(info.base).variant.(runtime.Type_Info_Integer); ok {
		signed = i.signed
	}

	current := runtime.Type_Info_Enum_Value(scene.int_value(data, size, signed))
	index := 0
	for v, i in info.values {
		if v == current {
			index = i
		}
	}

	ui.push_id(&ctx, label)
	defer ui.pop_id(&ctx)
	if !ui.button(&ctx, info.names[index]) {
		return false
	}

	next := i128(info.values[(index + 1) % len(info.values)])
	mem.copy(data, &next, size)
	return true
}

@(private="file")
float_value :: proc(data: rawptr, size: int) -> f64 {
	switch size {
	case 2: return f64((^f16)(data)^)
	case 4: return f64((^f32)(data)^)
	case 8: return (^f64)(data)^
	}
	return 0
}