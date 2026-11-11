package platform

Key :: enum u8 {
	A, B, C, D, E, F, G, H, I, J, K, L, M,
	N, O, P, Q, R, S, T, U, V, W, X, Y, Z,
	Num_0, Num_1, Num_2, Num_3, Num_4, Num_5, Num_6, Num_7, Num_8, Num_9,
	Up, Down, Left, Right,
	Space, Enter, Escape, Tab, Backspace,
	Left_Shift, Left_Control, Left_Alt,
}

Key_Set :: bit_set[Key]
