package vizcode

import "core:text/regex/parser"

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
ValueList :: list.List
ValueNode :: struct {
	using link: list.Node,
	val:        Value,
}

BinOpKind :: enum {
	Add,
	Sub,
	Mul,
	Div,
	And,
	LesserEqual,
	Lesser,
	Greater,
	GreaterEqual,
	Equal,
	BitXor,
	BitOr,
	BitAnd,
}


BinOp :: struct {
	kind:     BinOpKind,
	lhs, rhs: ^Expr,
}

Expr :: union {
	BinOp,
	Value,
	NativeFunctionCall,
}

Entry :: struct {}

Routine :: struct {
	args:   ValueList,
	blocks: BlockList,
}

Print :: struct {
	args: ValueList, // (PrimNode)
}

If :: struct {
	cond:   Expr,
	blocks: BlockList,
}

Else :: struct {
	blocks: BlockList,
}

Repeat :: struct {
	iters:  Value,
	blocks: BlockList,
}

PIO_SM_Put_Blocking :: struct {
	pio: Value,
	sm: Value,
	data: Value,
}

NativeFunctionCall :: struct {
	name: string,
	args: []Value,
	ret: Value,
}

Block :: struct {
	pos : vec2,
	using link: list.Node,
	kind:   union {
		Repeat,
		If,
		Else,
		Entry,
		Print,
		NativeFunctionCall,
	},
}

NativeFunctionCallNames :: enum {
	pio_sm_put_blocking,
	sleep_ms,
}

native_function_calls := [NativeFunctionCallNames]NativeFunctionCall {
	.pio_sm_put_blocking = {
		name = "pio_sm_put_blocking",
		args = []Value{
			i32(0), // pio
			i32(0), // sm
			i32(0), // data
		},
		ret = Value{},
	},
	.sleep_ms = {
		name = "sleep_ms",
		args = []Value{
			i32(0), // ms
		},
		ret = Value{},
	},
}

BlockList :: list.List

bin_op_str := [BinOpKind]string {
	.Add          = "+",
	.Sub          = "-",
	.Mul          = "*",
	.Div          = "/",
	.And          = "&&",
	.LesserEqual  = "<=",
	.GreaterEqual = ">=",
	.Lesser       = "<",
	.Greater      = ">",
	.Equal        = "==",
	.BitXor       = "^",
	.BitOr        = "|",
	.BitAnd       = "&",
}

// Error with the code below: args is an int but it wants a Value

// write_function_call_code_gen :: proc(b: ^strings.Builder, call: ^NativeFunctionCall) {
	// fmt.sbprintf(b, "%s(", call.name)
	// for i, arg in call.args {
		// write_value_code_gen(b, arg)
		// if i < len(call.args) - 1 do strings.write_string(b, ", ")
	// }
	// strings.write_string(b, ")")
// }

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

// Need to fix switch

//write_expr_code_gen :: proc(b: ^strings.Builder, expr: ^Expr) {
	//switch kind in expr {
	//case BinOp:
		//write_expr_code_gen(b, kind.lhs)
		//fmt.sbprintf(b, " %s ", bin_op_str[kind.kind])
		//write_expr_code_gen(b, kind.lhs)
	//case Value:
		//write_value_code_gen(b, kind)
	//}
//}

write_fmt_args_code_gen :: proc(b: ^strings.Builder, values: ValueList, sep := " ") {
	strings.write_byte(b, '"')
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
			strings.write_string(b, "%f")
		case string:
			strings.write_string(b, "%s")
		case:
			strings.write_string(b, "(nil)")
		}
		if node.next != nil do strings.write_string(b, sep)
	}
	strings.write_string(b, "\", ")

}

write_args_code_gen :: proc(b: ^strings.Builder, args: ValueList, sep := ", ") {
	iter := list.iterator_head(args, ValueNode, "link")
	for arg in list.iterate_next(&iter) {
		write_value_code_gen(b, arg.val)
		if arg.next != nil do strings.write_string(b, ", ")
	}
}

write_block_code_gen :: proc(b: ^strings.Builder, block: ^Block) {
	#partial switch kind in block.kind {
	case If:

	case Entry:

	case Print:
		strings.write_string(b, "printf(")
		write_fmt_args_code_gen(b, kind.args)
		write_args_code_gen(b, kind.args)
		strings.write_string(b, ");\n")
	}
}

write_block_list_code_gen :: proc(
	b: ^strings.Builder,
	blocks: BlockList,
	whitespace := "    ",
	level := 0,
) {
	iter := list.iterator_head(blocks, Block, "link")
	for block in list.iterate_next(&iter) {
		for i in 0 ..< level do strings.write_string(b, whitespace)
		write_block_code_gen(b, block)
	}
}

code_gen_test :: proc() {
	b := strings.builder_init(&{})
	args := ValueList{}
	vals := [?]ValueNode{{val = i32(2)}, {val = 3.141}, {val = "fart"}}
	for &val in vals {
		list.push_back(&args, &val)
	}
	fn_calls := [?]NativeFunctionCall{native_function_calls[.pio_sm_put_blocking], native_function_calls[.sleep_ms]}
	print := &Block{kind = Print{args}}
	write_block_code_gen(b, print)
	out := strings.to_string(b^)
	fmt.println(out)
}
