package vizcode


import "core:container/intrusive/list"

Prim :: union {
	i8,
	i16,
	i32,
	i64,
	f32,
	f64,
}

Stmt :: struct {
	using node: list.Node,
}
