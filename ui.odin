package vizcode


import "core:fmt"
import "core:unicode/utf8"
import mu "vendor:microui"
import rl "vendor:raylib"

render_blocks :: proc(s: ^Editor_State) {
	ui_render_pass(s)
}

render :: proc(s: ^Editor_State) {
	ctx := &state.mu_ctx
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

	render_blocks(s)

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

// ---------- NON TUTORIAL CODE BELOW ---------- //

Save_Load_UI_State :: struct {
	save_name_buf: [64]byte,
	save_name_len: int,
	show_load_picker: bool,
	save_list: [dynamic]string, // Refreshed every time picker is opened
}

@(private = "file")
save_load_ui: Save_Load_UI_State

@(private = "file")
refresh_save_list :: proc() {
	for s in save_load_ui.save_list do delete(s)
	clear(&save_load_ui.save_list)
	names := list_saves()
	for n in names do append(&save_load_ui.save_list, n)
}

taskbar_window :: proc(ctx: ^mu.Context, rect: ^mu.Rect, opts: ^mu.Options, editor: ^Editor_State) {
	if mu.window(ctx, "Top Task Bar", rect^, opts^) {
		mu.layout_row(ctx, {100, 100, 140, 50, 60, -90, -60, -30, -1})

		if build_status == .Idle {
			if .SUBMIT in mu.button(ctx, "Build") {
				launch_build()
			}
		} else {
			mu.button(ctx, "Building...")
		}
		if flash_status == .Idle {
			if .SUBMIT in mu.button(ctx, "Flash") {
				launch_flash()
			}
		} else {
			mu.button(ctx, "Flashing...")
		}
		
		mu.label(ctx, "") // Empty space

		mu.textbox(ctx, save_load_ui.save_name_buf[:], &save_load_ui.save_name_len)

		if .SUBMIT in mu.button(ctx, "Save") {
			name := string(save_load_ui.save_name_buf[:save_load_ui.save_name_len])
			if len(name) == 0 {
				write_log("Save: enter a name first")
			} else if save_editor_to_file(editor, name) {
				write_log(fmt.tprintf("Saved \"%s\"", name))
			} else {
				write_log(fmt.tprintf("Save failed for \"%s\"", name))
			}
		}

		load_label := save_load_ui.show_load_picker ? "Load ▴" : "Load ▾"
		if .SUBMIT in mu.button(ctx, load_label) {
			save_load_ui.show_load_picker = !save_load_ui.show_load_picker
			if save_load_ui.show_load_picker {
				refresh_save_list()
			}
		}

		mu.label(ctx, "") // Spacer
		if .SUBMIT in mu.button(ctx, "___", .NONE, mu.Options{.ALIGN_CENTER}) {
			rl.MinimizeWindow()
		}
		if .SUBMIT in mu.button(ctx, "[___]", .NONE, mu.Options{.ALIGN_CENTER}) {
			rl.MaximizeWindow()
		}
		if .SUBMIT in mu.button(ctx, "", .CLOSE, mu.Options{}) {
			rl.CloseWindow()
		}
	}
}

load_picker_window :: proc(ctx: ^mu.Context, editor: ^Editor_State, taskbar_h: i32) {
	if !save_load_ui.show_load_picker do return

	picker_rect := mu.Rect{rl.GetScreenWidth() - 280, taskbar_h, 260, 300}
	picker_opts := mu.Options{.NO_RESIZE}

	container := mu.get_container(ctx, "Load Save")
	if container != nil && !container.open {
		save_load_ui.show_load_picker = false
		return
	}

	if mu.window(ctx, "Load Save", picker_rect, picker_opts) {
		if len(save_load_ui.save_list) == 0 {
			mu.layout_row(ctx, {-1})
			mu.label(ctx, "No saves found in saves/")
		} else {
			mu.layout_row(ctx, {-1}, -28)
			mu.begin_panel(ctx, "Save List")
			for name in save_load_ui.save_list {
				mu.layout_row(ctx, {-1})
				if .SUBMIT in mu.button(ctx, name) {
					if load_editor_from_file(editor, name) {
						write_log(fmt.tprintf("Loaded \"%s\"", name))
					} else {
						write_log(fmt.tprintf("Load failed for \"%s\"", name))
					}
					save_load_ui.show_load_picker = false
				}
			}
			mu.end_panel(ctx)
		}

		mu.layout_row(ctx, {-1})
		if .SUBMIT in mu.button(ctx, "Refresh") {
			refresh_save_list()
		}
	}
}

// Create and render a popup displayed when:
// - the build is complete and waiting for RPI connection.
build_waiting_RPI_popup :: proc(ctx: ^mu.Context, rect: ^mu.Rect, opts: ^mu.Options) {
	if flash_status == .Waiting_For_RPI {
		if mu.window(ctx, "RPI Popup", rect^, opts^) {
			mu.layout_row(ctx, {-1})
			mu.label(ctx, "Plug in RPI while holding BOOT button")
			mu.layout_row(ctx, {-1})
			mu.label(ctx, "Waiting for device...")
		}
	}
}

// Create and render a popup displayed when
// - the built artifact is being transferred to the RPI device.
// build_transferring_popup :: proc(ctx: ^mu.Context, rect: ^mu.Rect, opts: ^mu.Options) {
// 	if build_status == .Transferring {
// 		if mu.window(ctx, "Flash Popup", rect^, opts^) {
// 			mu.layout_row(ctx, {-1})
// 			mu.label(ctx, "Transferring .uf2 to RPI...")
// 		}
// 	}
// }

// Create and render a popup displayed when
// - the built artifact has been successfully transferred to the RPI device.
// build_done_popup :: proc(ctx: ^mu.Context, rect: ^mu.Rect, opts: ^mu.Options) {
// 	if build_status == .Done {
// 		if mu.window(ctx, "Flash Popup", rect^, opts^) {
// 			mu.layout_row(ctx, {-1})
// 			mu.label(ctx, "Flash complete! RPI rebooting.")
// 		}
// 	}
// }


log_window :: proc(ctx: ^mu.Context, rect: ^mu.Rect, opts: ^mu.Options) {
	if mu.window(ctx, "Logs", rect^, opts^) {
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


@(private = "file")
// Convert a microui Rect to a new raylib Rectangle
//
// mu.Rect -> rl.Rectangle
rect_to_rectangle :: proc(rect: ^mu.Rect) -> rl.Rectangle {
	rectangle := rl.Rectangle{f32(rect.x), f32(rect.y), f32(rect.w), f32(rect.h)}
	return rectangle
}

@(private = "file")
// Draw a grid with a given colour, throughout a given Rectangle.
// More customizable than rl.DrawGrid
draw_coloured_rectangle_grid :: proc(rectangle: rl.Rectangle, spacing: f32, color: rl.Color) {
	for i := rectangle.x; i < rectangle.x + rectangle.width; i += spacing {
		rl.DrawLineV(
			rl.Vector2{i, rectangle.y},
			rl.Vector2{i, rectangle.y + rectangle.height},
			color,
		)
	}
	for i := rectangle.y; i < rectangle.y + rectangle.height; i += spacing {
		rl.DrawLineV(
			rl.Vector2{rectangle.x, i},
			rl.Vector2{rectangle.x + rectangle.width, i},
			color,
		)
	}
}

dummy_editor_window :: proc(ctx: ^mu.Context, rect: ^mu.Rect, opts: ^mu.Options) {
	rl.BeginDrawing()
	if mu.window(ctx, "Editor", rect^, opts^) {
		rl.DrawRectangleRec(rect_to_rectangle(rect), rl.BLACK)
		draw_coloured_rectangle_grid(rect_to_rectangle(rect), 16, rl.DARKGRAY)
	}
	// Causes flashing in renders
	// rl.EndDrawing()

}

all_windows :: proc(ctx: ^mu.Context, editor: ^Editor_State) {
	taskbar_window_opts := mu.Options{.NO_RESIZE, .NO_SCROLL, .NO_CLOSE, .NO_TITLE}
	taskbar_window_rect := mu.Rect{0, 0, rl.GetScreenWidth(), rl.GetScreenHeight() / 16}
	taskbar_window(ctx, &taskbar_window_rect, &taskbar_window_opts, editor)

	build_waiting_RPI_popup_rect := mu.Rect{300, 200, 360, 100}
	build_waiting_RPI_popup_opts := mu.Options{.NO_CLOSE, .NO_RESIZE}
	build_waiting_RPI_popup(ctx, &build_waiting_RPI_popup_rect, &build_waiting_RPI_popup_opts)

	// build_transferring_popup_rect := mu.Rect{300, 200, 300, 80}
	// build_transferring_popup_opts := mu.Options{.NO_RESIZE}
	// build_transferring_popup(ctx, &build_transferring_popup_rect, &build_transferring_popup_opts)

	// build_done_popup_rect := build_transferring_popup_rect
	// build_done_popup_opts := build_transferring_popup_opts
	// build_done_popup(ctx, &build_done_popup_rect, &build_done_popup_opts)

	log_window_opts := mu.Options{.NO_INTERACT, .NO_RESIZE, .NO_CLOSE}
	log_window_rect := mu.Rect {
		0, // Top left corner, under top taskbar
		0 + taskbar_window_rect.h, // Should not intrude on top taskbar
		rl.GetScreenWidth() / 4, // Should comprise one-quarter of the screen
		rl.GetScreenHeight() - taskbar_window_rect.h,
	}
	log_window(ctx, &log_window_rect, &log_window_opts)

	editor_window_opts := mu.Options{.NO_FRAME, .NO_RESIZE, .NO_CLOSE, .NO_TITLE}
	// Consume the remainder of the screen space
	editor_window_rect := mu.Rect {
		log_window_rect.x + log_window_rect.w, // Left-bounded by logging window
		taskbar_window_rect.y + taskbar_window_rect.h, // Upper-bounded by taskbar
		rl.GetScreenWidth() - (log_window_rect.x + log_window_rect.w), // Remaining width
		rl.GetScreenHeight() - (taskbar_window_rect.y + taskbar_window_rect.h), // Remaining height
	}
	// THE EDITOR WINDOW SHOULD BE DEFINED USING THIS WINDOW.
	// IMPORT THE EDITOR WINDOW-CREATING FUNCTION LOGIC WITH THE PARAMETERS:
	// editor_window(ctx: ^mu.Context, rect: ^mu.Rect, opts: ^mu.Options)
	dummy_editor_window(ctx, &editor_window_rect, &editor_window_opts)

	load_picker_window(ctx, editor, taskbar_window_rect.h)
}
