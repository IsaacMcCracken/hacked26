package vizcode

import "core:container/intrusive/list"

Editor_State :: struct 
{
	ui_blocks:	[dynamic]^UI_Block,
	mouse_pos:  vec2
}

UI_Block :: struct
{
	pos		 : vec2,
	size	 : vec2,
	hovered  : bool,
	selected : bool,
	using link : list.Node,
	children   : list.List
}

init_editor :: proc(state: ^Editor_State)
{
	blocks := &state.ui_blocks
	// Create and add 3 root blocks
	b1 := new(UI_Block)

	b2 := new(UI_Block)
	b2A := new(UI_Block)
	b2B := new(UI_Block)

	b3 := new(UI_Block)


	b2^ = UI_Block{pos = {200, 25}, size = {50, 50}}


	b1^ = UI_Block{pos = {25, 25},	size = {100, 100}}


	b3^ = UI_Block{pos = {300, 25}, size = {50, 75}}

	append(blocks, b1, b2, b3)
}

mouse_in_block :: proc(block: ^UI_Block, mp: vec2) -> bool
{
	in_x := mp.x >= block.pos.x && mp.x <= (block.pos.x + block.size.x)
	in_y := mp.y >= block.pos.y && mp.y <= (block.pos.y + block.size.y)

	return in_x && in_y
}

get_hovered_block :: proc(block: ^UI_Block, s: ^Editor_State, base_depth : u32 = 0) -> (hovered: ^UI_Block, depth: u32)
{
	// Lowest hovered block
	h: ^UI_Block
	// Depth of lowest hovered block
	d := base_depth

	// Check if self is hovered
	if (mouse_in_block(block, s.mouse_pos)) { h = block }
	else {block.hovered = false}

	iter := list.iterator_head(block.children, UI_Block, "link")
	for child in list.iterate_next(&iter)
	{
		hovered_child, child_depth := get_hovered_block(child, s, base_depth + 1)
		if (child != nil && child_depth > d)
		{
			h = hovered_child
			d = child_depth
		}
	}

	return h, d
}

find_hovered_block :: proc(root_blocks: ^[dynamic]^UI_Block, state: ^Editor_State)
{
	// check each root block for selection
	first_hovered : ^UI_Block
	loopy : for block in root_blocks
	{
		hovered_block, depth := get_hovered_block(block, state)
		if (hovered_block != nil)
		{
			first_hovered = hovered_block
			break loopy
		}
	}

	if (first_hovered != nil)
	{
		first_hovered.hovered = true;
	}
}

update_editor :: proc(state: ^Editor_State, mouse_pos: vec2)
{
	state.mouse_pos = mouse_pos
	// TODO(rordon): layout pass

	// TODO(rordon): selection pass
	find_hovered_block(&state.ui_blocks, state)
}
