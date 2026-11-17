package ui

begin_panel :: proc(ctx: ^Context, title: string, rect: ^Rect, docked := false) {
	assert(ctx.panel == 0, "panels don't nest")
	push_id(ctx, title)
	ctx.panel = ctx.id_stack[len(ctx.id_stack) - 1]

	title_h := ctx.theme.font_size + 2 * ctx.theme.padding
	bar := Rect{rect.pos, {rect.size.x, title_h}}

	id := get_id(ctx, "title bar")

	if !docked {
		update_control(ctx, id, bar)
		if ctx.active == id {
			if .Left in ctx.mouse_pressed {
				ctx.drag_offset = ctx.mouse - rect.pos
			}
			rect.pos = ctx.mouse - ctx.drag_offset
			bar.pos = rect.pos
		}
	}

    append(&ctx.panels, Panel_Range{ctx.panel, rect^, len(ctx.commands), 0, docked})

	push_rect(ctx, rect^, ctx.theme.panel)
	push_rect(ctx, bar, ctx.active == id ? ctx.theme.accent : ctx.theme.title)
	push_text(ctx, title, bar.pos + ctx.theme.padding, ctx.theme.text)

	content := Rect{rect.pos + {0, title_h}, rect.size - {0, title_h}}
	push_clip(ctx, content)

	start := content.pos + ctx.theme.padding
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