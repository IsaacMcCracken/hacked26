package vizcode


import "core:fmt"
import "core:unicode/utf8"
import mu "vendor:microui"
import rl "vendor:raylib"

render_blocks :: proc(blocks: ^[dynamic]^UI_Block) {
	for block in blocks {
		rl.DrawRectangleV(block.pos, block.size, rl.RED)
	}
}

render :: proc(ctx: ^mu.Context, ui_blocks: ^[dynamic]^UI_Block) {
	// Renders glyphs, icons on the texture atlas.
	render_texture :: proc(rect: mu.Rect, pos: [2]i32, color: mu.Color) {
		source := rl.Rectangle{f32(rect.x), f32(rect.y), f32(rect.w), f32(rect.h)}
		position := rl.Vector2{f32(pos.x), f32(pos.y)}

		rl.DrawTextureRec(state.atlas_texture, source, position, transmute(rl.Color)color)
	}

	rl.ClearBackground(transmute(rl.Color)state.bg)

	rl.BeginDrawing()
	defer rl.EndDrawing()

	rl.BeginScissorMode(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight())
	defer rl.EndScissorMode()

	render_blocks(ui_blocks)

	command_backing: ^mu.Command
	for variant in mu.next_command_iterator(ctx, &command_backing) {
		switch cmd in variant {
		case ^mu.Command_Text:
			pos := [2]i32{cmd.pos.x, cmd.pos.y}
			for ch in cmd.str do if ch & 0xc0 != 0x80 {
				r := min(int(ch), 127)
				rect := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r]
				render_texture(rect, pos, cmd.color)
				pos.x += rect.w
			}
		case ^mu.Command_Rect:
			rl.DrawRectangle(
				cmd.rect.x,
				cmd.rect.y,
				cmd.rect.w,
				cmd.rect.h,
				transmute(rl.Color)cmd.color,
			)
		case ^mu.Command_Icon:
			rect := mu.default_atlas[cmd.id]
			x := cmd.rect.x + (cmd.rect.w - rect.w) / 2
			y := cmd.rect.y + (cmd.rect.h - rect.h) / 2
			render_texture(rect, {x, y}, cmd.color)
		case ^mu.Command_Clip:
			rl.EndScissorMode()
			rl.BeginScissorMode(cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h)
		case ^mu.Command_Jump:
			unreachable()
		}
	}

}


u8_slider :: proc(ctx: ^mu.Context, val: ^u8, lo, hi: u8) -> (res: mu.Result_Set) {
	mu.push_id(ctx, uintptr(val))

	@(static) tmp: mu.Real
	tmp = mu.Real(val^)
	res = mu.slider(ctx, &tmp, mu.Real(lo), mu.Real(hi), 0, "%.0f", {.ALIGN_CENTER})
	val^ = u8(tmp)
	mu.pop_id(ctx)
	return
}

write_log :: proc(str: string) {
	state.log_buf_len += copy(state.log_buf[state.log_buf_len:], str)
	state.log_buf_len += copy(state.log_buf[state.log_buf_len:], "\n")
	state.log_buf_updated = true
}

read_log :: proc() -> string {
	return string(state.log_buf[:state.log_buf_len])
}
reset_log :: proc() {
	state.log_buf_updated = true
	state.log_buf_len = 0
}


block :: proc(ctx: ^mu.Context, hover: bool, show_snap_target: bool) {
	@(static) opts := mu.Options{.NO_CLOSE, .NO_TITLE, .NO_RESIZE, .NO_SCROLL, .AUTO_SIZE}
	if mu.window(ctx, "block", {10, 10, 120, 100}, opts) {
		@(static) buf: [128]byte
		@(static) buf_len: int
		mu.layout_row(ctx, {50, 70})
		mu.label(ctx, "Repeat:")
		if .SUBMIT in mu.textbox(ctx, buf[:], &buf_len) {

			mu.set_focus(ctx, ctx.last_id)
		}


		if (hover) {ctx.style.colors[.BORDER] = mu.Color{255, 0, 0, 255}}
		mu.layout_row(ctx, {-1}, 100)
		mu.begin_panel(ctx, "Log")
		ctx.style.colors[.BORDER] = mu.Color{25, 25, 25, 255} // default
		mu.end_panel(ctx)


		if show_snap_target {
			mu.layout_row(ctx, {-1}, 20)

			// Save old window background color
			old_bg := ctx.style.colors[.WINDOW_BG]

			// Set your custom color (RGBA)
			ctx.style.colors[.WINDOW_BG] = mu.Color {
				r = 50,
				g = 150,
				b = 200,
				a = 255,
			} // light blue

			mu.begin_panel(ctx, "Snap Target")
			mu.end_panel(ctx)

			// Restore previous color
			ctx.style.colors[.WINDOW_BG] = old_bg
		}
	}
}

demo_windows :: proc(ctx: ^mu.Context, opts: ^mu.Options) {
	if mu.window(ctx, "Demo Window", {40, 40, 300, 450}, opts^) {
		if .ACTIVE in mu.header(ctx, "Window Info") {
			win := mu.get_current_container(ctx)
			mu.layout_row(ctx, {54, -1}, 0)
			mu.label(ctx, "Position:")
			mu.label(ctx, fmt.tprintf("%d, %d", win.rect.x, win.rect.y))
			mu.label(ctx, "Size:")
			mu.label(ctx, fmt.tprintf("%d, %d", win.rect.w, win.rect.h))
		}

		if .ACTIVE in mu.header(ctx, "Window Options") {
			mu.layout_row(ctx, {120, 120, 120}, 0)
			for opt in mu.Opt {
				state := opt in opts^
				if .CHANGE in mu.checkbox(ctx, fmt.tprintf("%v", opt), &state) {
					if state {
						opts^ += {opt}
					} else {
						opts^ -= {opt}
					}
				}
			}
		}

		if .ACTIVE in mu.header(ctx, "Test Buttons", {.EXPANDED}) {
			mu.layout_row(ctx, {86, -110, -1})
			mu.label(ctx, "Test buttons 1:")
			if .SUBMIT in mu.button(ctx, "Button 1") {write_log("Pressed button 1")}
			if .SUBMIT in mu.button(ctx, "Button 2") {write_log("Pressed button 2")}
			mu.label(ctx, "Test buttons 2:")
			if .SUBMIT in mu.button(ctx, "Button 3") {write_log("Pressed button 3")}
			if .SUBMIT in mu.button(ctx, "Button 4") {write_log("Pressed button 4")}
		}

		if .ACTIVE in mu.header(ctx, "Tree and Text", {.EXPANDED}) {
			mu.layout_row(ctx, {140, -1})
			mu.layout_begin_column(ctx)
			if .ACTIVE in mu.treenode(ctx, "Test 1") {
				if .ACTIVE in mu.treenode(ctx, "Test 1a") {
					mu.label(ctx, "Hello")
					mu.label(ctx, "world")
				}
				if .ACTIVE in mu.treenode(ctx, "Test 1b") {
					if .SUBMIT in mu.button(ctx, "Button 1") {write_log("Pressed button 1")}
					if .SUBMIT in mu.button(ctx, "Button 2") {write_log("Pressed button 2")}
				}
			}
			if .ACTIVE in mu.treenode(ctx, "Test 2") {
				mu.layout_row(ctx, {53, 53})
				if .SUBMIT in mu.button(ctx, "Button 3") {write_log("Pressed button 3")}
				if .SUBMIT in mu.button(ctx, "Button 4") {write_log("Pressed button 4")}
				if .SUBMIT in mu.button(ctx, "Button 5") {write_log("Pressed button 5")}
				if .SUBMIT in mu.button(ctx, "Button 6") {write_log("Pressed button 6")}
			}
			if .ACTIVE in mu.treenode(ctx, "Test 3") {
				@(static) checks := [3]bool{true, false, true}
				mu.checkbox(ctx, "Checkbox 1", &checks[0])
				mu.checkbox(ctx, "Checkbox 2", &checks[1])
				mu.checkbox(ctx, "Checkbox 3", &checks[2])

			}
			mu.layout_end_column(ctx)

			mu.layout_begin_column(ctx)
			mu.layout_row(ctx, {-1})
			mu.text(
				ctx,
				"Lorem ipsum dolor sit amet, consectetur adipiscing " +
				"elit. Maecenas lacinia, sem eu lacinia molestie, mi risus faucibus " +
				"ipsum, eu varius magna felis a nulla.",
			)
			mu.layout_end_column(ctx)
		}

		if .ACTIVE in mu.header(ctx, "Background Colour", {.EXPANDED}) {
			mu.layout_row(ctx, {-78, -1}, 68)
			mu.layout_begin_column(ctx)
			{
				mu.layout_row(ctx, {46, -1}, 0)
				mu.label(ctx, "Red:"); u8_slider(ctx, &state.bg.r, 0, 255)
				mu.label(ctx, "Green:"); u8_slider(ctx, &state.bg.g, 0, 255)
				mu.label(ctx, "Blue:"); u8_slider(ctx, &state.bg.b, 0, 255)
			}
			mu.layout_end_column(ctx)

			r := mu.layout_next(ctx)
			mu.draw_rect(ctx, r, state.bg)
			mu.draw_box(ctx, mu.expand_rect(r, 1), ctx.style.colors[.BORDER])
			mu.draw_control_text(
				ctx,
				fmt.tprintf("#%02x%02x%02x", state.bg.r, state.bg.g, state.bg.b),
				r,
				.TEXT,
				{.ALIGN_CENTER},
			)
		}
	}

	if mu.window(ctx, "Log Window", {350, 40, 300, 200}, opts^) {
		mu.layout_row(ctx, {-1}, -28)
		mu.begin_panel(ctx, "Log")
		mu.layout_row(ctx, {-1}, -1)
		mu.text(ctx, read_log())
		if state.log_buf_updated {
			panel := mu.get_current_container(ctx)
			panel.scroll.y = panel.content_size.y
			state.log_buf_updated = false
		}
		mu.end_panel(ctx)

		@(static) buf: [128]byte
		@(static) buf_len: int
		submitted := false
		mu.layout_row(ctx, {-70, -1})
		if .SUBMIT in mu.textbox(ctx, buf[:], &buf_len) {
			mu.set_focus(ctx, ctx.last_id)
			submitted = true
		}
		if .SUBMIT in mu.button(ctx, "Submit") {
			submitted = true
		}
		if submitted {
			write_log(string(buf[:buf_len]))
			buf_len = 0
		}
	}

	if mu.window(ctx, "Style Window", {350, 250, 300, 240}) {
		@(static) colors := #partial [mu.Color_Type]string {
			.TEXT         = "text",
			.BORDER       = "border",
			.WINDOW_BG    = "window bg",
			.TITLE_BG     = "title bg",
			.TITLE_TEXT   = "title text",
			.PANEL_BG     = "panel bg",
			.BUTTON       = "button",
			.BUTTON_HOVER = "button hover",
			.BUTTON_FOCUS = "button focus",
			.BASE         = "base",
			.BASE_HOVER   = "base hover",
			.BASE_FOCUS   = "base focus",
			.SCROLL_BASE  = "scroll base",
			.SCROLL_THUMB = "scroll thumb",
		}

		sw := i32(f32(mu.get_current_container(ctx).body.w) * 0.14)
		mu.layout_row(ctx, {80, sw, sw, sw, sw, -1})
		for label, col in colors {
			mu.label(ctx, label)
			u8_slider(ctx, &ctx.style.colors[col].r, 0, 255)
			u8_slider(ctx, &ctx.style.colors[col].g, 0, 255)
			u8_slider(ctx, &ctx.style.colors[col].b, 0, 255)
			u8_slider(ctx, &ctx.style.colors[col].a, 0, 255)
			mu.draw_rect(ctx, mu.layout_next(ctx), ctx.style.colors[col])
		}
	}
}

all_windows :: proc(ctx: ^mu.Context) {
	@(static) opts := mu.Options{.NO_CLOSE}

	// Tutorial code. Comment out for final product
	// demo_windows(ctx, &opts)

	// Top action taskbar
	bottom_taskbar_opts := mu.Options{.NO_INTERACT, .NO_RESIZE, .NO_SCROLL, .NO_CLOSE, .NO_TITLE}
	bottom_taskbar_rect := mu.Rect{0, 0, rl.GetScreenWidth(), rl.GetScreenHeight() / 10}
	if mu.window(ctx, "Lower Window", bottom_taskbar_rect, bottom_taskbar_opts) {
		mu.layout_row(ctx, {120})
		if .SUBMIT in mu.button(ctx, "Compile and Run") {
			write_log("Compile and run the code!")
		}
	}

	// Log window
	log_window_opts := mu.Options{.NO_INTERACT, .NO_RESIZE, .NO_CLOSE}
	log_window_rect := mu.Rect {
		0, // Top left corner, under top taskbar
		0 + bottom_taskbar_rect.h, // Should not intrude on top taskbar
		rl.GetScreenWidth() / 4, // Should comprise one-quarter of the screen
		rl.GetScreenHeight() - bottom_taskbar_rect.h, 
	} 
	if mu.window(ctx, "Logs", log_window_rect, log_window_opts) {
	    mu.layout_row(ctx, {-1}, -1)
    	mu.begin_panel(ctx, "Log", mu.Options{.AUTO_SIZE})
        mu.layout_row(ctx, {-1}, -1)
		mu.text(ctx, read_log())
		if state.log_buf_updated {
			panel := mu.get_current_container(ctx)
			panel.scroll.y = panel.content_size.y
			state.log_buf_updated = false
		}
		mu.end_panel(ctx)
	}
}
