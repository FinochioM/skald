package ui

import "skald:platform"

FIRA_CODE :: #load("fonts/FiraCode-Regular.ttf")

load_default_font :: proc(pf: ^platform.Interface, size: f32) -> platform.Font {
	return pf.load_font(FIRA_CODE, size)
}