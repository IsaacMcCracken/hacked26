package vizcode

import "core:container/intrusive/list"
import "core:container/small_array"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:path/filepath"

SAVES_DIR :: "saves"

// Use this because JSON can't use intrusive lists, 
// so we need a way to represent the UI_Blocks in a flat file
UI_Block_JSON :: struct {
    kind:     UI_Block_Kind,
    text:     string,
    pos_x:    f32,
    pos_y:    f32,
    children: []UI_Block_JSON,
}

// ---------- HELPERS ---------- //

ensure_saves_dir :: proc() -> bool {
    if os.is_dir(SAVES_DIR) do return true
    err := os.make_directory(SAVES_DIR)
    if err != os.ERROR_NONE {
        fmt.eprintln("[serialize] could not create saves dir:", err)
        return false
    }
    return true
}

// Build the full path for a save file given a bare name (no extension)
save_path :: proc(name: string, allocator := context.allocator) -> string {
    base := strings.trim_suffix(name, ".json")
    return filepath.join({SAVES_DIR, strings.concatenate({base, ".json"}, allocator)}, allocator)
}

// Return a slice of bare save names (no directory/extension) found in SAVES_DIR
// Whatever calls needs to delete the slice and each string inside
list_saves :: proc(allocator := context.allocator) -> []string {
    names := make([dynamic]string, 0, 8, allocator)

    dh, err := os.open(SAVES_DIR)
    if err != os.ERROR_NONE do return names[:]

    defer os.close(dh)

    infos, read_err := os.read_dir(dh, -1, allocator)
    if read_err != os.ERROR_NONE do return names[:]
    defer delete(infos, allocator)

    for info in infos {
        if strings.has_suffix(info.name, ".json") {
            bare := strings.trim_suffix(info.name, ".json")
            append(&names, strings.clone(bare, allocator))
        }
    }

    return names[:]
}

// ---------- SERIALIZATION ---------- //

@(private)
ui_block_to_json_struct :: proc(b: ^UI_Block, allocator := context.allocator) -> UI_Block_JSON {
    child_count := 0
    {
        iter := list.iterator_head(b.children, UI_Block, "link")
        for _ in list.iterate_next(&iter) do child_count += 1
    }

    children_slice := make([]UI_Block_JSON, child_count, allocator)
    {
        iter := list.iterator_head(b.children, UI_Block, "link")
        i := 0
        for child in list.iterate_next(&iter) {
            children_slice[i] = ui_block_to_json_struct(child, allocator)
            i += 1
        }
    }

    return UI_Block_JSON{
        kind     = b.kind,
        text     = string(small_array.slice(&b.text)),
        pos_x    = b.pos.x,
        pos_y    = b.pos.y,
        children = children_slice,
    }
}

serialize_editor :: proc(
    state: ^Editor_State,
    allocator := context.allocator,
) -> (data: []byte, err: json.Marshal_Error) {
    roots := make([]UI_Block_JSON, len(state.ui_blocks), allocator)
    defer delete(roots, allocator)

    for block, i in state.ui_blocks {
        roots[i] = ui_block_to_json_struct(block, allocator)
    }

    opt := json.Marshal_Options{pretty = true}
    return json.marshal(roots, opt, allocator)
}

save_editor_to_file :: proc(state: ^Editor_State, name: string) -> bool {
    if !ensure_saves_dir() do return false

    data, marshal_err := serialize_editor(state)
    if marshal_err != nil {
        fmt.eprintln("[serialize] marshal error:", marshal_err)
        return false
    }
    defer delete(data)

    path := save_path(name)
    defer delete(path)

    ok := os.write_entire_file(path, data)
    if !ok {
        fmt.eprintln("[serialize] failed to write", path)
        return false
    }

    fmt.println("[serialize] saved to", path)
    return true
}

// ---------- DESERIALIZATION ---------- //

@(private)
ui_block_from_json_struct :: proc(src: UI_Block_JSON) -> ^UI_Block {
    b := new(UI_Block)
    b.kind = src.kind
    b.pos  = {src.pos_x, src.pos_y}

    for ch in transmute([]u8)src.text {
        if !small_array.push_back(&b.text, ch) do break
    }

    for &child_src in src.children {
        push_child_block(b, ui_block_from_json_struct(child_src))
    }

    return b
}

load_editor_from_file :: proc(state: ^Editor_State, name: string) -> bool {
    path := save_path(name)
    defer delete(path)

    data, ok := os.read_entire_file(path)
    if !ok {
        fmt.eprintln("[serialize] failed to read", path)
        return false
    }
    defer delete(data)

    roots: []UI_Block_JSON
    unmarshal_err := json.unmarshal(data, &roots)
    if unmarshal_err != nil {
        fmt.eprintln("[serialize] unmarshal error:", unmarshal_err)
        return false
    }
    defer delete(roots)

    clear(&state.ui_blocks)
    for &root_src in roots {
        append(&state.ui_blocks, ui_block_from_json_struct(root_src))
    }

    fmt.println("[serialize] loaded from", path)
    return true
}
