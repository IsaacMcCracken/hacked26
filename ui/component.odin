package ui

import "core:fmt"
import "core:reflect"
import "core:strings"
import rl "vendor:raylib"

Rectangle :: rl.Rectangle
Texture :: rl.Texture
Vector2 :: rl.Vector2

Render_Flags :: bit_set[Render_Flag;u8]
Render_Flag :: enum {
	Render,
}

Index :: i16

Component :: struct {
	next, prev: Index,
	gen:        i16,
	rec:        Rectangle,
}
