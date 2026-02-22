package vizcode

import "core:container/intrusive/list"
import "core:container/small_array"
import "core:fmt"
import rl "vendor:raylib"

Editor_State :: struct {
	ui_blocks: [dynamic]^UI_Block,
	mouse_pos: vec2,
}


UI_Kind_Flags :: bit_set[UI_Kind_Flag;u8]
UI_Kind_Flag :: enum {
	Pregnable,
	Name,
	Input,
	VArgs,
}

UI_Kind_Render_Data :: struct {
	name:        string,
	flags:       UI_Kind_Flags,
	input_types: []typeid,
}

UI_Block_Kind :: enum {
	If,
	Else,
	While,
}


UI_Block :: struct {
	using link: list.Node,
	text:       small_array.Small_Array(32, u8),
	input:      ^UI_Block,
	pos:        vec2,
	size:       vec2,
	hovered:    bool,
	selected:   bool,
	children:   list.List,
	parent:		^UI_Block
}

push_child_block :: proc(parent, child: ^UI_Block)
{
	child.parent = parent
	list.push_back(&parent.children, child)
}

kind_render_data := [UI_Block_Kind]UI_Kind_Render_Data {
	.If = {name = "if"},
	.Else = {name = "else"},
	.While = {},
}

init_editor :: proc(state: ^Editor_State) {
	blocks := &state.ui_blocks

	a := new(UI_Block)
	b := new(UI_Block)
	c := new(UI_Block)

	a.pos = {300, 100}
	push_child_block(a, b)
	push_child_block(a, c)

	append(blocks, a)
}

mouse_in_block :: proc(block: ^UI_Block, mp: vec2) -> bool {
	in_x := mp.x >= block.pos.x && mp.x <= (block.pos.x + block.size.x)
	in_y := mp.y >= block.pos.y && mp.y <= (block.pos.y + block.size.y)

	return in_x && in_y
}

get_hovered_block :: proc(
	block: ^UI_Block,
	s: ^Editor_State,
	base_depth: u32 = 0,
) -> (
	hovered: ^UI_Block,
	depth: u32,
) {
	// Lowest hovered block
	h: ^UI_Block
	// Depth of lowest hovered block
	d := base_depth

	// Check if self is hovered
	block.hovered = false
	if (mouse_in_block(block, s.mouse_pos))
	{
		h = block
	}

	iter := list.iterator_head(block.children, UI_Block, "link")
	for child in list.iterate_next(&iter) {
		hovered_child, child_depth := get_hovered_block(child, s, base_depth + 1)
		if (hovered_child != nil && child_depth > d) {
			h = hovered_child
			d = child_depth
		}
	}

	return h, d
}

find_hovered_block :: proc(root_blocks: ^[dynamic]^UI_Block, state: ^Editor_State) {
	// check each root block for selection
	first_hovered: ^UI_Block
	loopy: for block in root_blocks {
		hovered_block, depth := get_hovered_block(block, state)
		if (hovered_block != nil) {
			first_hovered = hovered_block
			break loopy
		}
	}

	if (first_hovered != nil) {
		first_hovered.hovered = true
	}
}


ui_render_pass :: proc(s: ^Editor_State) {
	ui_render_block :: proc(s: ^Editor_State, b: ^UI_Block) {
		rec := rl.Rectangle {
			x      = b.pos.x,
			y      = b.pos.y,
			width  = b.size.x,
			height = b.size.y,
		}
		rl.DrawRectangleRec(rec, rl.DARKGRAY)
		outlineColor := rl.RAYWHITE
		if (b.hovered) { outlineColor = rl.BLACK }
		rl.DrawRectangleLinesEx(rec, 2, outlineColor)

		iter := list.iterator_head(b.children, UI_Block, "link")
		for child in list.iterate_next(&iter) {
			ui_render_block(s, child)
		}
	}

	for block in s.ui_blocks {
		ui_render_block(s, block)
	}
}

ui_layout_pass :: proc(s: ^Editor_State) {
	ui_layout_block :: proc(s: ^Editor_State, b: ^UI_Block, p: ^UI_Block = nil, level := 0) {
		DEFAULT_SPACE :: 2
		DEFAULT_SIZE :: vec2{200, 30}
		DEFAULT_MARGIN :: 15
		b.size = DEFAULT_SIZE

		// if it has a parent we change the size
		if p != nil {
			b.pos.x = p.pos.x + DEFAULT_MARGIN
			prev := transmute(^UI_Block)b.prev
			if prev == nil {
				b.pos.y = p.pos.y + DEFAULT_MARGIN
			} else {
				b.pos.y = prev.pos.y + prev.size.y + DEFAULT_SPACE
			}
		}

		// if we have children we change our size
		if !list.is_empty(&b.children) {
			iter := list.iterator_head(b.children, UI_Block, "link")
			count := 0
			for child in list.iterate_next(&iter) {
				count += 1
				ui_layout_block(s, child, b, level + 1)
			}

			tail := transmute(^UI_Block)b.children.tail
			rel := tail.pos - b.pos
			b.size.y = rel.y + tail.size.y + DEFAULT_MARGIN
		}

	}

	for root in s.ui_blocks {
		ui_layout_block(s, root)
	}
}


update_editor :: proc(state: ^Editor_State, mouse_pos: vec2, mouse_left_down: bool) {
	state.mouse_pos = mouse_pos
	// TODO(rordon): layout pass
	ui_layout_pass(state)

	// TODO(rordon): selection pass
	find_hovered_block(&state.ui_blocks, state)
}
