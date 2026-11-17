package ui

import "skald:platform"

Theme :: struct {
	font_size: f32,
	padding: f32,
	spacing: f32,
	slider_width: f32,
    field_width: f32,

	text: platform.Color,
	button: platform.Color,
	button_hot: platform.Color,
	button_active: platform.Color,
	accent: platform.Color,
	panel: platform.Color,
	title: platform.Color,
}

DEFAULT_THEME :: Theme {
	font_size = 16,
	padding = 8,
	spacing = 6,
	slider_width = 200,
    field_width = 200,

	text = {220, 220, 225, 255},
	button = {60, 60, 70, 255},
	button_hot = {75, 75, 90, 255},
	button_active = {45, 45, 55, 255},
	accent = {90, 140, 220, 255},
	panel = {36, 36, 42, 255},
	title = {52, 52, 62, 255},
}

set_scale :: proc(ctx: ^Context, font: platform.Font, scale: f32, theme := DEFAULT_THEME) {
	ctx.font = font
	ctx.scale = scale

	ctx.theme = theme
	ctx.theme.font_size *= scale
	ctx.theme.padding *= scale
	ctx.theme.spacing *= scale
	ctx.theme.slider_width *= scale
	ctx.theme.field_width *= scale
}