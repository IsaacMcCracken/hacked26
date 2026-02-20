package vizcode

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

Entity :: struct {
	next, prev: Index,
	gen:        i16,
	pos:        Rectangle,
	tex:        Texture,
	rec:        Rectangle,
}


write_entity_struct :: proc(b: ^strings.Builder) {
	id := typeid_of(Entity)
	fields := reflect.struct_fields_zipped(id)
	strings.write_string(b, "typedef struct Entity Entity;\n")
	strings.write_string(b, "Entity {\n")
	for field in fields {
		// fmt.tprintf(b, "    ")
	}

	strings.write_string(b, "};\n")
}
