package skald

import "base:runtime"
import "core:strings"

Collection_Field :: struct {
	name: string,
	offset: uintptr,
	item: ^runtime.Type_Info,
}

find_collections :: proc(ti: ^runtime.Type_Info, allocator := context.allocator) -> [dynamic]Collection_Field {
	found := make([dynamic]Collection_Field, allocator)

	s, ok := runtime.type_info_base(ti).variant.(runtime.Type_Info_Struct)
	if !ok {
		return found
	}

	for i in 0 ..< s.field_count {
		if item := collection_item(s.types[i]); item != nil {
			append(&found, Collection_Field{name = s.names[i], offset = s.offsets[i], item = item})
		}
	}

	return found
}

collection_item :: proc(ti: ^runtime.Type_Info) -> ^runtime.Type_Info {
	named, is_named := ti.variant.(runtime.Type_Info_Named)
	if !is_named || named.pkg != "skald" || !strings.has_prefix(named.name, "Collection(") {
		return nil
	}

	c := runtime.type_info_base(ti).variant.(runtime.Type_Info_Struct)
	slots := c.types[0].variant.(runtime.Type_Info_Dynamic_Array)
	slot := runtime.type_info_base(slots.elem).variant.(runtime.Type_Info_Struct)
	return slot.types[0]
}