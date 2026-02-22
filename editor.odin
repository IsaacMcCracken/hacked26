package vizcode

import "core:container/intrusive/list"
import "core:container/small_array"
import "core:fmt"
import rl "vendor:raylib"

DEFAULT_SPACE :: 2
BLOCK_SIZE :: vec2{200, 30}
EXPR_SIZE :: vec2{60, 25}
MARGIN_SIDE :: 10
MARGIN_TOP :: 15
MARGIN_BOT :: 5
MARGIN_INPUT :: MARGIN_TOP + EXPR_SIZE.y + MARGIN_BOT

Editor_State :: struct {
	ui_blocks:       [dynamic]^UI_Block,
	mouse_pos:       vec2,
	hovered_block:   ^UI_Block,
	selected_block:  ^UI_Block,
	selected_offset: vec2,
}


UI_Kind_Flags :: bit_set[UI_Kind_Flag;u8]
UI_Kind_Flag :: enum {
	Pregnable,
	Siblingable,
	Name,
	Inputable,
	Expr,
	VArgs,
}

UI_Kind_Data :: struct {
	name:        string,
	flags:       UI_Kind_Flags,
	input_types: []typeid,
	input_names: []string,
}

UI_Block_Kind :: enum {
	None,
	If,
	Else,
	While,
}


UI_Block :: struct {
	using link: list.Node,
	text:       small_array.Small_Array(32, u8),
	inputs:     [16]^UI_Block,
	kind:       UI_Block_Kind,
	pos:        vec2,
	size:       vec2,
	selected:   bool,
	children:   list.List,
	parent:     ^UI_Block,
}


ui_kind_data := [UI_Block_Kind]UI_Kind_Data {
	.None = {name = ""},
	.If = {
		name = "IF",
		flags = {.Siblingable, .Pregnable, .Inputable, .Name},
		input_types = {i32},
		input_names = {"cond"},
	},
	.Else = {name = "ELSE", flags = {.Siblingable, .Pregnable, .Name}},
	.While = {
		name = "IF",
		flags = {.Siblingable, .Pregnable, .Inputable, .Name},
		input_types = {i32},
		input_names = {"cond"},
	},
}

push_child_block :: proc(parent, child: ^UI_Block) {
	child.parent = parent
	list.push_back(&parent.children, child)
}


init_editor :: proc(state: ^Editor_State) {
	blocks := &state.ui_blocks

	a := new(UI_Block)
	b := new(UI_Block)
	c := new(UI_Block)

	d := new(UI_Block)
	d.kind = .If
	d.pos = {400, 200}

	a.kind = .If
	a.pos = {300, 100}
	push_child_block(a, b)
	push_child_block(a, c)

	append(blocks, a, d)
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

	if (mouse_in_block(block, s.mouse_pos)) {
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

find_hovered_block :: proc(root_blocks: ^[dynamic]^UI_Block, state: ^Editor_State) -> ^UI_Block {
	// Find the foremost hovered block
	first_hovered: ^UI_Block
	loopy: for block in root_blocks {
		hovered_block, depth := get_hovered_block(block, state)
		if (hovered_block != nil) {
			first_hovered = hovered_block
		}
	}

	return first_hovered
}

get_empty_pregnable :: proc(block: ^UI_Block, s: ^Editor_State) -> ^UI_Block {
	pregnable_block: ^UI_Block = nil

	data := ui_kind_data[block.kind]

	// Check if current block is pregnable and empty
	if (.Pregnable in data.flags && list.is_empty(&block.children)) {
		preg_rec := ui_pregnable_rec(block)
		if (rl.CheckCollisionPointRec(s.mouse_pos, preg_rec)) {
			pregnable_block = block
		}
	}

	// Check if any of the children of the block are pregnable and empty
	iter := list.iterator_head(block.children, UI_Block, "link")
	for child in list.iterate_next(&iter) {
		pregnable_child := get_empty_pregnable(child, s)
		if (pregnable_child != nil) {
			pregnable_block = pregnable_child
		}
	}

	return pregnable_block
}

find_empty_pregnable :: proc(state: ^Editor_State) -> ^UI_Block
{
	for root_block in state.ui_blocks
	{
		if root_block != state.selected_block
		{
			empty_preg_block := get_empty_pregnable(root_block, state)
			if (empty_preg_block != nil) { return empty_preg_block }
		}
	}
	return nil
}

ui_pregnable_rec :: proc(b: ^UI_Block) -> rl.Rectangle {
	rec := rl.Rectangle {
		x      = b.pos.x,
		y      = b.pos.y,
		width  = b.size.x,
		height = b.size.y,
	}
	data := ui_kind_data[b.kind]
	xmargin: f32 = MARGIN_SIDE
	ymargin: f32 = MARGIN_TOP
	if .Pregnable in data.flags do ymargin = MARGIN_INPUT
	return rl.Rectangle {
		x = rec.x + xmargin,
		y = rec.y + ymargin,
		width = BLOCK_SIZE.x,
		height = BLOCK_SIZE.y,
	}
}
ui_inputable_rec :: proc(b: ^UI_Block, idx: int) -> rl.Rectangle {
	rec := rl.Rectangle {
		x      = b.pos.x,
		y      = b.pos.y,
		width  = b.size.x,
		height = b.size.y,
	}
	data := ui_kind_data[b.kind]
	xmargin: f32 = MARGIN_SIDE + (f32(idx) * 2)
	ymargin: f32 = MARGIN_TOP
	if .Pregnable in data.flags do ymargin = MARGIN_INPUT
	return rl.Rectangle {
		x = rec.x + xmargin,
		y = rec.y + ymargin,
		width = BLOCK_SIZE.x,
		height = BLOCK_SIZE.y,
	}
}

ui_render_pass :: proc(s: ^Editor_State) {
	ui_render_block :: proc(s: ^Editor_State, b: ^UI_Block) {
		data := ui_kind_data[b.kind]
		rec := rl.Rectangle {
			x      = b.pos.x,
			y      = b.pos.y,
			width  = b.size.x,
			height = b.size.y,
		}
		rl.DrawRectangleRec(rec, rl.DARKGRAY)
		outlineColor := rl.RAYWHITE
		if (b == s.hovered_block) {outlineColor = rl.BLACK}
		if (b.selected) {outlineColor = rl.YELLOW}

		if .Pregnable in data.flags {
			preg_rec := ui_pregnable_rec(b)
			rl.DrawRectangleRec(preg_rec, {40, 40, 40, 255})
			rl.DrawRectangleLinesEx(preg_rec, 2, outlineColor)

		}

		if .Siblingable in data.flags
		{
			if (s.selected_block != nil)
			{
				selected_block_data := ui_kind_data[b.kind]
				if (.Siblingable in selected_block_data.flags)
				{
					outlineColor = rl.RED
				}
			}
		}

		rl.DrawRectangleLinesEx(rec, 2, outlineColor)
		if .Inputable in data.flags {
			for name, i in data.input_names {
				input := b.inputs[i]
				if input != nil do ui_render_block(s, input)
			}
		}


		iter := list.iterator_head(b.children, UI_Block, "link")
		for child in list.iterate_next(&iter) {
			ui_render_block(s, child)
		}

		if .Name in data.flags {
			render_text(data.name, b.pos + {5, 5}, outlineColor)
		}
	}

	for block in s.ui_blocks {
		ui_render_block(s, block)
	}
}

ui_layout_pass :: proc(s: ^Editor_State) {
	ui_layout_block :: proc(s: ^Editor_State, b: ^UI_Block, level := 0) {
		data := ui_kind_data[b.kind]


		b.size = BLOCK_SIZE

		if .Inputable in data.flags {
			b.size.y = MARGIN_INPUT
		}

		p := b.parent
		// if it has a parent we change the size
		if p != nil {
			b.pos = p.pos
			b.pos.x += MARGIN_SIDE

			pdata := ui_kind_data[p.kind]

			prev := transmute(^UI_Block)b.prev
			if prev == nil {
				ymargin: f32 = MARGIN_TOP
				if .Inputable in pdata.flags do ymargin = MARGIN_INPUT
				b.pos.y += ymargin
			} else {
				b.pos.y = prev.pos.y + prev.size.y + DEFAULT_SPACE
			}
		}

		if .Inputable in data.flags {
			if .Expr not_in data.flags {
				xstart: f32 = MARGIN_SIDE
				n := len(data.input_types)
				inputs := b.inputs[:n]
				for &input in inputs {
					if input != nil do ui_layout_block(s, input)
				}
			}
		}

		// if we have children we change our size
		if !list.is_empty(&b.children) {
			iter := list.iterator_head(b.children, UI_Block, "link")
			count := 0
			for child in list.iterate_next(&iter) {
				count += 1
				ui_layout_block(s, child)
			}

			tail := transmute(^UI_Block)b.children.tail
			rel := tail.pos - b.pos
			b.size.y = rel.y + tail.size.y + MARGIN_BOT
		} else {
			if .Pregnable in data.flags {
				b.size.y += BLOCK_SIZE.y + MARGIN_BOT
			}
		}

	}

	for root in s.ui_blocks {
		ui_layout_block(s, root)
	}
}

set_selected :: proc(block: ^UI_Block, value: bool) {
	block.selected = value

	iter := list.iterator_head(block.children, UI_Block, "link")
	for child in list.iterate_next(&iter) {
		set_selected(child, value)
	}
}

remove_root_block :: proc(s: ^Editor_State, b: ^UI_Block) {
	for c_i := 0; c_i < len(s.ui_blocks); c_i += 1 {
		if (s.ui_blocks[c_i] == b) {
			ordered_remove(&s.ui_blocks, c_i)
			break
		}
	}
}

// Selected a hovered block
select_block :: proc(s: ^Editor_State) {
	if (s.hovered_block != nil && s.selected_block == nil) {
		s.selected_block = s.hovered_block
		set_selected(s.selected_block, true)
		offset := s.selected_block.pos - s.mouse_pos
		s.selected_offset = offset
		if (s.selected_block.parent != nil) {
			list.remove(&s.selected_block.parent.children, s.selected_block)
			s.selected_block.parent = nil
		} else {
			// The block is a root block. Before we move it to the back of the dynamic array,
			// we need to delete the pointer to that root block and increment the rest of the
			// dynamic array.
			remove_root_block(s, s.selected_block)
		}
		// Move the block to the back of the dynamic array
		append(&s.ui_blocks, s.selected_block)
	}
}


unselect_block :: proc(s: ^Editor_State) {
	if (s.selected_block != nil) {
		// check for pregrable interactions
		preg_block := find_empty_pregnable(s)
		if (preg_block != nil) {
			// put selected block in preg_block
			push_child_block(preg_block, s.selected_block)
			remove_root_block(s, s.selected_block)
		}
		set_selected(s.selected_block, false)
		s.selected_block = nil
	}
}


update_editor :: proc(state: ^Editor_State, mouse_pos: vec2, mouse_left_down: bool) {
	state.mouse_pos = mouse_pos
	// TODO(rordon): layout pass
	ui_layout_pass(state)

	// TODO(rordon): selection pass
	state.hovered_block = find_hovered_block(&state.ui_blocks, state)
	if (state.selected_block != nil) {
		state.selected_block.pos = mouse_pos + state.selected_offset
	}

	if (mouse_left_down) {
		select_block(state)
	} else if (state.selected_block != nil) {
		unselect_block(state)
	}
}
