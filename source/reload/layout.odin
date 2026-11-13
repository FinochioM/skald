package reload

import "base:runtime"
import "core:hash"

layout_hash :: proc(ti: ^runtime.Type_Info) -> u64 {
	return hash_type(ti, hash.fnv64a(nil), 0)
}

@(private)
hash_type :: proc(ti: ^runtime.Type_Info, h: u64, depth: int) -> u64 {
	h := h
	if ti == nil {
		return mix(h, "nil")
	}
	h = mix_int(h, ti.size)
	h = mix_int(h, ti.align)

	if depth > 16 {
		return h
	}

	#partial switch v in ti.variant {
	case runtime.Type_Info_Named:
		h = hash_type(v.base, h, depth + 1)
	case runtime.Type_Info_Struct:
		h = mix(h, "struct")
		for i in 0 ..< int(v.field_count) {
			h = mix(h, v.names[i])
			h = mix_int(h, int(v.offsets[i]))
			h = hash_type(v.types[i], h, depth + 1)
		}
	case runtime.Type_Info_Integer:
		h = mix(h, "int")
		h = mix_int(h, int(v.signed))
	case runtime.Type_Info_Float:
		h = mix(h, "float")
	case runtime.Type_Info_Boolean:
		h = mix(h, "bool")
	case runtime.Type_Info_String:
		h = mix(h, "string")
	case runtime.Type_Info_Enum:
		h = mix(h, "enum")
		for name in v.names {
			h = mix(h, name)
		}
	case runtime.Type_Info_Array:
		h = mix(h, "array")
		h = mix_int(h, v.count)
		h = hash_type(v.elem, h, depth + 1)
	case runtime.Type_Info_Dynamic_Array:
		h = mix(h, "dynamic")
		h = hash_type(v.elem, h, depth + 1)
	case runtime.Type_Info_Pointer:
		h = mix(h, "pointer")
	case:
		// todounions, maps, slices, bit_sets by their parts. for now only size and align count
		h = mix(h, "other")
	}

	return h
}

@(private)
mix :: proc(h: u64, s: string) -> u64 {
	return hash.fnv64a(transmute([]byte)s, h)
}

@(private)
mix_int :: proc(h: u64, x: int) -> u64 {
	x := x
	return hash.fnv64a(([^]byte)(&x)[:size_of(x)], h)
}