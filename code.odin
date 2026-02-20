package vizcode


import "core:container/intrusive/list"

Prim :: union {
	i8,
	i16,
	i32,
	i64,
	f32,
	f64,
	string,
}

PrimNode :: struct {
	using link: list.Node,
	val:        Prim,
}

Entry :: struct {}

Routine :: struct {}

Print :: struct {}


Block :: struct {
	using node: list.Node,
	kind:       union {
		Entry,
	},
}
