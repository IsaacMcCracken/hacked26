package vizcode

import mu "vendor:microui"
import rl "vendor:raylib"


render_texture :: proc(rect: mu.Rect, pos: vec2, color: rl.Color) {
	source := rl.Rectangle{f32(rect.x), f32(rect.y), f32(rect.w), f32(rect.h)}
	position := rl.Vector2{f32(pos.x), f32(pos.y)}

	rl.DrawTextureRec(state.atlas_texture, source, position, transmute(rl.Color)color)
}

render_text :: proc(str: string, pos: vec2, color: rl.Color) {
	pos := pos
	for ch in str do if ch & 0xc0 != 0x80 {
		r := min(int(ch), 127)
		rect := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r]
		render_texture(rect, pos, color)
		pos.x += f32(rect.w)
	}
}
