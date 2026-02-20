package vizcode


import "core:container/intrusive/list"
import "core:fmt"
import "core:strings"

ptr :: ^Value
Value :: union {
	i8,
	i16,
	i32,
	f32,
	string,
	ptr,
}


ValueNode :: struct {
	using link: list.Node,
	val:        Value,
}

ValueList :: list.List

Entry :: struct {}

Routine :: struct {
	args:   ValueList,
	blocks: BlockList,
}

Print :: struct {
	args: ValueList, // (PrimNode)
}

Repeat :: struct {
	iters:  Value,
	blocks: BlockList,
}


Block :: struct {
	using link: list.Node,
	kind:       union {
		Entry,
		Print,
	},
}

BlockList :: list.List

write_value_code_gen :: proc(b: ^strings.Builder, value: Value) {
	#partial switch val in value {
	case i8:
		strings.write_int(b, int(val))
	case i16:
		strings.write_int(b, int(val))
	case i32:
		strings.write_int(b, int(val))
	case f32:
		strings.write_f32(b, val, 'f')
	case string:
		fmt.sbprintf(b, "\"%s\"", val)
	case ptr:
	}
}

write_fmt_args_code_gen :: proc(b: ^strings.Builder, values: ValueList, sep := " ") {
	iter := list.iterator_head(values, ValueNode, "link")
	for node in list.iterate_next(&iter) {
		value := node.val
		#partial switch val in value {
		case ptr:
			strings.write_string(b, "%p")
		case i8:
			strings.write_string(b, "%d")
		case i16:
			strings.write_string(b, "%d")
		case i32:
			strings.write_string(b, "%d")
		case f32:
			strings.write_string(b, "%d")
		case string:
			strings.write_string(b, "%s")
		case:
			strings.write_string(b, "(nil)")
		}
		strings.write_string(b, sep)
	}

}

write_block_code_gen :: proc(b: ^strings.Builder, block: ^Block) {
	switch kind in block.kind {
	case Entry:

	case Print:
		strings.write_string(b, "printf(")
		write_fmt_args_code_gen(b, kind.args)
		iter := list.iterator_head(kind.args, ValueNode, "link")
		for node in list.iterate_next(&iter) {
			// value := node.val

		}
	}

}
