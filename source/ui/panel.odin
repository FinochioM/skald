package ui

import "skald:platform"

PANEL_COLOR :: platform.Color{36, 36, 42, 255}
TITLE_COLOR :: platform.Color{52, 52, 62, 255}

begin_panel :: proc(ctx: ^Context, title: string, rect: ^Rect) {
	assert(ctx.panel == 0, "panels don't nest")
	push_id(ctx, title)
	ctx.panel = ctx.id_stack[len(ctx.id_stack) - 1]

	title_h := ctx.font_size + 2 * PADDING
	bar := Rect{rect.pos, {rect.size.x, title_h}}

	id := get_id(ctx, "title bar")
	update_control(ctx, id, bar)
	if ctx.active == id {
		if .Left in ctx.mouse_pressed {
			ctx.drag_offset = ctx.mouse - rect.pos
		}
		rect.pos = ctx.mouse - ctx.drag_offset
		bar.pos = rect.pos
	}

    append(&ctx.panels, Panel_Range{ctx.panel, rect^, len(ctx.commands), 0})

	push_rect(ctx, rect^, PANEL_COLOR)
	push_rect(ctx, bar, ctx.active == id ? ACCENT_COLOR : TITLE_COLOR)
	push_text(ctx, title, bar.pos + PADDING, TEXT_COLOR)

	content := Rect{rect.pos + {0, title_h}, rect.size - {0, title_h}}
	push_clip(ctx, content)

	start := content.pos + PADDING
	append(&ctx.layouts, Layout{.Column, start, start, start})
}

end_panel :: proc(ctx: ^Context) {
	pop(&ctx.layouts)
	pop_clip(ctx)
	pop_id(ctx)

	ctx.panels[len(ctx.panels) - 1].last = len(ctx.commands)
	ctx.panel = 0
}

@(deferred_in=end_panel_scoped)
panel :: proc(ctx: ^Context, title: string, rect: ^Rect) {
	begin_panel(ctx, title, rect)
}

@(private)
end_panel_scoped :: proc(ctx: ^Context, title: string, rect: ^Rect) {
	end_panel(ctx)
}