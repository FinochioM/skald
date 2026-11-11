package skald

import "core:testing"

@(test)
test_press_is_seen_by_one_tick :: proc(t: ^testing.T) {
	Action :: enum {
		Jump,
		Restart,
	}
	bindings := [Action]Binding {
		.Jump    = {.Space, .W},
		.Restart = {.R},
	}

	input: Input

	input_update(&input, {.Space})
	input_update(&input, {.Space})
	testing.expect(t, action_pressed(input, bindings, .Jump))
	testing.expect(t, !action_pressed(input, bindings, .Restart))
	input_consume(&input)

	testing.expect(t, !action_pressed(input, bindings, .Jump))
	testing.expect(t, action_down(input, bindings, .Jump))

	input_update(&input, {})
	input_update(&input, {.W})
	testing.expect(t, action_pressed(input, bindings, .Jump))
}
