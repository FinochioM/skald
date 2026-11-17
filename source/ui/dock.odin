package ui

split :: proc(ctx: ^Context, label: string, r: Rect, dir: Direction, ratio: ^f32) -> (first, second: Rect) {
    axis := dir == .Row ? 0 : 1
    gap := ctx.theme.spacing
    room := r.size[axis] - gap

    id := get_id(ctx, label)
    bar := r
    bar.pos[axis] = r.pos[axis] + room * ratio^

    bar.size[axis] = gap

    update_control(ctx, id, bar)
    if ctx.active == id {
        ratio^ = clamp((ctx.mouse[axis] - gap / 2 - r.pos[axis]) / room, 0.05, 0.95)
        bar.pos[axis] = r.pos[axis] + room * ratio^
    }

    if ctx.active == id || ctx.hot == id {
        push_rect(ctx, bar, ctx.theme.accent)
    }

    first, second = r, r
    first.size[axis] = bar.pos[axis] - r.pos[axis]

    second.pos[axis] = bar.pos[axis] + gap
    second.size[axis] = r.pos[axis] + r.size[axis] - second.pos[axis]

    return
}

begin_dock :: proc(ctx: ^Context, title: string, r: Rect) {
    r := r
    begin_panel(ctx, title, &r, docked = true)
}

end_dock :: end_panel

@(deferred_in=end_dock_scoped)
dock :: proc(ctx: ^Context, title: string, r: Rect) {
    begin_dock(ctx, title, r)
}

@(private)
end_dock_scoped :: proc(ctx: ^Context, title: string, r: Rect) {
    end_panel(ctx)
}