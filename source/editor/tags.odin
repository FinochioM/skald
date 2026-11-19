package main

import "core:strconv"
import "core:strings"

Inspect_Tag :: struct {
	hide: bool,
	color: bool,
	ranged: bool,
	lo, hi: f64,
}

parse_inspect_tag :: proc(text: string) -> (tag: Inspect_Tag) {
	rest := text
	for option in strings.fields_iterator(&rest) {
		key, _, value := strings.partition(option, "=")
		switch key {
		case "hide":
			tag.hide = true
		case "color":
			tag.color = true
		case "range":
			lo_text, _, hi_text := strings.partition(value, ",")
			lo, lo_ok := strconv.parse_f64(lo_text)
			hi, hi_ok := strconv.parse_f64(hi_text)
			if lo_ok && hi_ok && lo < hi {
				tag.ranged, tag.lo, tag.hi = true, lo, hi
			}
		}
	}
	return
}