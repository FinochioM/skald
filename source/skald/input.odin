package skald

import "skald:platform"

Key :: platform.Key
Key_Set :: platform.Key_Set

Binding :: Key_Set

Input :: struct {
	down: Key_Set,

	pressed: Key_Set,
}

input_update :: proc(input: ^Input, down_now: Key_Set) {
	input.pressed += down_now - input.down
	input.down = down_now
}

input_consume :: proc(input: ^Input) {
	input.pressed = {}
}

action_down :: proc(input: Input, bindings: [$A]Binding, action: A) -> bool {
	return input.down & bindings[action] != {}
}

action_pressed :: proc(input: Input, bindings: [$A]Binding, action: A) -> bool {
	return input.pressed & bindings[action] != {}
}
