package vizcode

when ODIN_OS != .Windows {
	foreign import libc "system:c"

	foreign libc {
		system :: proc(command: cstring) -> i32 ---
	}
}
import "core:container/intrusive/list"
import "core:os"
import "core:strings"
import "core:thread"
import "core:unicode/utf8"
import mu "vendor:microui"
import rl "vendor:raylib"

vec2 :: rl.Vector2


state := struct {
	mu_ctx:          mu.Context,
	log_buf:         [1 << 16]byte,
	log_buf_len:     int,
	log_buf_updated: bool,
	bg:              mu.Color,
	atlas_texture:   rl.Texture2D,
	root_blocks:     [dynamic]^Block,
	ui_blocks:       [dynamic]^UI_Block,
} {
	bg = {90, 95, 100, 255},
}

Script_Status :: enum {
	Idle,
	Running,
	Waiting_For_RPI,
}

build_status: Script_Status = .Idle
flash_status: Script_Status = .Idle

BUILD_STATUS_FILE :: "/tmp/vizcode_build_status"
FLASH_STATUS_FILE :: "/tmp/vizcode_flash_status"

build_thread_proc :: proc(t: ^thread.Thread) {
	when ODIN_OS != .Windows {
		system("bash ./build.sh")
	}
}

flash_thread_proc :: proc(t: ^thread.Thread) {
	when ODIN_OS != .Windows {
		system("bash ./flash.sh")
	}
}

launch_build :: proc() {
	build_status = .Running
	t := thread.create(build_thread_proc)
	thread.start(t)
}

launch_flash :: proc() {
	flash_status = .Running
	t := thread.create(flash_thread_proc)
	thread.start(t)
}

poll_build_status :: proc() {
	if build_status == .Idle do return

	data, ok := os.read_entire_file(BUILD_STATUS_FILE)
	if !ok do return
	defer delete(data)

	switch strings.trim_space(string(data)) {
	case "DONE":
		write_log("Build finished")
		build_status = .Idle
	}
}

poll_flash_status :: proc() {
	if flash_status == .Idle do return

	data, ok := os.read_entire_file(FLASH_STATUS_FILE)
	if !ok do return
	defer delete(data)

	switch strings.trim_space(string(data)) {
	case "WAITING_FOR_RPI":
		flash_status = .Waiting_For_RPI
	case "DONE":
		write_log("Flash finished")
		flash_status = .Idle
	}
}

main :: proc() {
	code_gen_test()

	// Initialize Editor Context
	editor_state := Editor_State{}
	init_editor(&editor_state)

	rl.InitWindow(960, 540, "microui-odin")
	defer rl.CloseWindow()

	pixels := make([][4]u8, mu.DEFAULT_ATLAS_WIDTH * mu.DEFAULT_ATLAS_HEIGHT)
	for alpha, i in mu.default_atlas_alpha {
		pixels[i] = {0xff, 0xff, 0xff, alpha}
	}
	defer delete(pixels)

	image := rl.Image {
		data    = raw_data(pixels),
		width   = mu.DEFAULT_ATLAS_WIDTH,
		height  = mu.DEFAULT_ATLAS_HEIGHT,
		mipmaps = 1,
		format  = .UNCOMPRESSED_R8G8B8A8,
	}
	state.atlas_texture = rl.LoadTextureFromImage(image)
	defer rl.UnloadTexture(state.atlas_texture)

	ctx := &state.mu_ctx
	mu.init(ctx)

	ctx.text_width = mu.default_atlas_text_width
	ctx.text_height = mu.default_atlas_text_height

	rl.SetTargetFPS(60)

	g := Repeat{}
	printBlockA := &Block{}
	printBlockB := &Block{}
	list.push_back(&g.blocks, printBlockA)
	list.push_back(&g.blocks, printBlockB)

	repeatBlock := &Block{kind = g}

	main_loop: for !rl.WindowShouldClose() {
		// mouse coordinates
		mouse_pos := [2]i32{rl.GetMouseX(), rl.GetMouseY()}
		mu.input_mouse_move(ctx, mouse_pos.x, mouse_pos.y)
		mu.input_scroll(ctx, 0, i32(rl.GetMouseWheelMove() * -30))

		// Update Editor
		update_editor(&editor_state, rl.GetMousePosition(), rl.IsMouseButtonDown(.LEFT))


		{ 	// text input
			text_input: [512]byte = ---
			text_input_offset := 0
			for text_input_offset < len(text_input) {
				ch := rl.GetCharPressed()
				if ch == 0 {
					break
				}
				b, w := utf8.encode_rune(ch)
				copy(text_input[text_input_offset:], b[:w])
				text_input_offset += w
			}
			mu.input_text(ctx, string(text_input[:text_input_offset]))
		}


		// mouse buttons
		@(static) buttons_to_key := [?]struct {
			rl_button: rl.MouseButton,
			mu_button: mu.Mouse,
		}{{.LEFT, .LEFT}, {.RIGHT, .RIGHT}, {.MIDDLE, .MIDDLE}}
		for button in buttons_to_key {
			if rl.IsMouseButtonPressed(button.rl_button) {
				mu.input_mouse_down(ctx, mouse_pos.x, mouse_pos.y, button.mu_button)
			} else if rl.IsMouseButtonReleased(button.rl_button) {
				mu.input_mouse_up(ctx, mouse_pos.x, mouse_pos.y, button.mu_button)
			}

		}

		// keyboard
		@(static) keys_to_check := [?]struct {
			rl_key: rl.KeyboardKey,
			mu_key: mu.Key,
		} {
			{.LEFT_SHIFT, .SHIFT},
			{.RIGHT_SHIFT, .SHIFT},
			{.LEFT_CONTROL, .CTRL},
			{.RIGHT_CONTROL, .CTRL},
			{.LEFT_ALT, .ALT},
			{.RIGHT_ALT, .ALT},
			{.ENTER, .RETURN},
			{.KP_ENTER, .RETURN},
			{.BACKSPACE, .BACKSPACE},
		}
		for key in keys_to_check {
			if rl.IsKeyPressed(key.rl_key) {
				mu.input_key_down(ctx, key.mu_key)
			} else if rl.IsKeyReleased(key.rl_key) {
				mu.input_key_up(ctx, key.mu_key)
			}
		}

		poll_build_status()
		poll_flash_status()

		mu.begin(ctx)
		all_windows(ctx)
		mu.end(ctx)

		render(&editor_state)
	}
}
