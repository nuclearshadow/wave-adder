package wave_adder

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

BACKGROUND_COLOR :: rl.Color{ 0x18, 0x18, 0x18, 0xFF }
UI_BACKGROUND_COLOR :: rl.BLACK
UI_FOREGROUND_COLOR :: rl.WHITE
UI_BORDER_COLOR :: rl.GRAY
UI_ACTIVE_BORDER_COLOR :: rl.BLUE
UI_BUTTON_COLOR :: rl.Color{ 0x24, 0x24, 0x3A, 0xFF }
UI_FONT_SIZE :: 24
UI_LABEL_FONT_SIZE :: 18


scissor_stack: [dynamic]rl.Rectangle = {}
push_scissor :: proc(rect: rl.Rectangle) {
    scissor_rect := rect
    if len(scissor_stack) != 0 {
        parent := scissor_stack[len(scissor_stack) - 1]

        x1 := math.max(rect.x, parent.x)
        y1 := math.max(rect.y, parent.y)
        x2 := math.min(rect.x + rect.width,  parent.x + parent.width)
        y2 := math.min(rect.y + rect.height, parent.y + parent.height)

        scissor_rect = rl.Rectangle{ x1, y1, math.max(0, x2 - x1), math.max(0, y2 - y1) }
    }
    append(&scissor_stack, scissor_rect)
    rl.BeginScissorMode(cast(i32)scissor_rect.x, cast(i32)scissor_rect.y, 
                        cast(i32)scissor_rect.width, cast(i32)scissor_rect.height)
}

pop_scissor :: proc() {
    if len(scissor_stack) == 0 {
        return
    }
    
    pop(&scissor_stack)

    if len(scissor_stack) == 0 {
        rl.EndScissorMode()
    } else {
        rect := scissor_stack[len(scissor_stack) - 1]
        rl.BeginScissorMode(cast(i32)rect.x, cast(i32)rect.y,
                            cast(i32)rect.width, cast(i32)rect.height)
    }
}

scroll_control :: proc(bounds: rl.Rectangle, var: ^f32, sensitivity: f32 = 1.0) -> bool {
    @static active_var: ^f32
    @static last_mouse_pos: rl.Vector2
    mouse := rl.GetMousePosition()
    if active_var == nil && rl.CheckCollisionPointRec(mouse, bounds) && rl.IsMouseButtonDown(rl.MouseButton.LEFT) {
        active_var = var

        last_mouse_pos = mouse
        rl.DisableCursor()
    }
    if active_var == var {
        var^ += rl.GetMouseDelta().x * sensitivity
        rl.SetMousePosition(auto_cast last_mouse_pos.x, auto_cast last_mouse_pos.y)
        
        if rl.IsMouseButtonReleased(rl.MouseButton.LEFT) {
            active_var = nil
            
            rl.EnableCursor()
            rl.SetMousePosition(auto_cast last_mouse_pos.x, auto_cast last_mouse_pos.y)
        }
        return true
    }
    return false
}

number_scroll_input :: proc(bounds: rl.Rectangle, var: ^f32) {
    is_active := scroll_control(bounds, var, 0.1)
    rl.DrawRectangleRec(bounds, UI_BACKGROUND_COLOR)
    rl.DrawRectangleLinesEx(bounds, 1, is_active ? UI_ACTIVE_BORDER_COLOR : UI_BORDER_COLOR)
    num_text := rl.TextFormat("%.2f", var^)
    rl.DrawText(
        num_text, 
        auto_cast (bounds.x + bounds.width/2) - rl.MeasureText(num_text, UI_FONT_SIZE)/2, 
        auto_cast (bounds.y + bounds.height/2 - auto_cast UI_FONT_SIZE * 0.4),
        UI_FONT_SIZE, UI_FOREGROUND_COLOR)
}

angle_scroll_input :: proc(position: rl.Vector2, size: f32, var: ^f32) {
    is_active := scroll_control(rl.Rectangle{ position.x, position.y, size, size }, var, 0.1)
    var^ = math.mod(var^, 2*math.PI)
    if var^ < 0 {
        var^ += 2*math.PI
    }
    radius := size/2
    center := position + radius
    rl.DrawCircleV(center, radius, UI_BACKGROUND_COLOR)
    vec := rl.Vector2Rotate(rl.Vector2{ 0, -1 }, var^) * radius
    rl.DrawLineEx(center, center + vec, 3, UI_FOREGROUND_COLOR)
    rl.DrawCircleLinesV(center, radius, is_active ? UI_ACTIVE_BORDER_COLOR : UI_BORDER_COLOR)
}

button :: proc(bounds: rl.Rectangle, text: cstring) -> bool {
    is_hovering := rl.CheckCollisionPointRec(rl.GetMousePosition(), bounds)
    rl.DrawRectangleRec(bounds, UI_BUTTON_COLOR)
    rl.DrawRectangleLinesEx(bounds, 1, is_hovering && rl.IsMouseButtonDown(.LEFT) ? UI_ACTIVE_BORDER_COLOR : UI_BORDER_COLOR)
    rl.DrawText(
        text, 
        auto_cast (bounds.x + bounds.width/2) - rl.MeasureText(text, UI_FONT_SIZE)/2, 
        auto_cast (bounds.y + bounds.height/2 - auto_cast UI_FONT_SIZE * 0.4),
        UI_FONT_SIZE, rl.WHITE)
    return rl.IsMouseButtonPressed(.LEFT) && is_hovering
}

verticle_scroll_bar :: proc(bounds: rl.Rectangle, content_height: f32, content_offset: ^f32) {
    @static active_var: ^f32
    @static mouse_offset: f32
    
    handle_rect := bounds
    border_color := UI_BORDER_COLOR
    // NOTE: This assumes that the view height is the same as the bar's height
    if content_height < bounds.height {
        content_offset^ = 0
    } else {
        // NOTE: This assumes that the view height is the same as the bar's height
        //       actual formula with view height as separate variable would be:
        //           handle_height = (view_height / content_height) * bounds.height
        handle_height := (bounds.height / content_height) * bounds.height        
        
        handle_rect.height = handle_height
        handle_rect.y += (content_offset^ / content_height) * bounds.height
        
        mouse := rl.GetMousePosition()
        if active_var == nil && rl.IsMouseButtonPressed(.LEFT) && rl.CheckCollisionPointRec(mouse, bounds) {
            active_var = content_offset
            mouse_offset = rl.CheckCollisionPointRec(mouse, handle_rect) ? mouse.y - handle_rect.y : handle_height / 2
        }
        if active_var == content_offset {
            normalized_offset := math.clamp((mouse.y - (bounds.y + mouse_offset)) / (bounds.height), 0, 1 - (handle_height / bounds.height))
            content_offset^ = normalized_offset * content_height
    
            if rl.IsMouseButtonReleased(.LEFT) {
                active_var = nil
            }
            border_color = UI_ACTIVE_BORDER_COLOR
        }
    }


    rl.DrawRectangleRec(bounds, UI_BACKGROUND_COLOR)
    rl.DrawRectangleLinesEx(bounds, 1.0, UI_BORDER_COLOR)
    rl.DrawRectangleRec(handle_rect, UI_BUTTON_COLOR)
    rl.DrawRectangleLinesEx(handle_rect, 1.0, border_color)
}


Wave :: struct {
    frequency: f32,
    amplitutde: f32,
    phase: f32,
    // Only used for visuals
    hue: f32,
}

sample_wave :: proc(t: f32, params: rawptr) -> f32 {
    wave := cast(^Wave)params
    return math.sin(2 * math.PI * wave.frequency * t + wave.phase) * wave.amplitutde
}

sample_waves_sum :: proc(t: f32, params: rawptr) -> f32 {
    waves := cast(^[]Wave)params
    sum: f32 = 0
    for &wave in waves {
        sum += sample_wave(t, &wave)
    }
    return sum
}

draw_wave :: proc(bounds: rl.Rectangle, sample_proc: proc(t: f32, params: rawptr) -> f32, sample_proc_params: rawptr, wave_color: rl.Color, cycle_width: f32 = 1.0, amplitutde_scale: f32 = 1.0) {
    rl.DrawRectangleRec(bounds, UI_BACKGROUND_COLOR)
    SAMPLE_INTERVAL :: 0.5
    freq_scale := 1 / cycle_width
    x: f32 = 0.0
    push_scissor(bounds)
    for x < bounds.width {
        y := sample_proc(x * freq_scale, sample_proc_params) * amplitutde_scale
        x2 := math.min(x + SAMPLE_INTERVAL, bounds.width)
        y2 := sample_proc(x2 * freq_scale, sample_proc_params) * amplitutde_scale
        rl.DrawLineV(
            rl.Vector2{bounds.x + x,  bounds.y + 0.5 * bounds.height - y }, 
            rl.Vector2{bounds.x + x2, bounds.y + 0.5 * bounds.height - y2}, 
            wave_color)
        x += SAMPLE_INTERVAL
    }
    pop_scissor()
    rl.DrawRectangleLinesEx(bounds, 1, UI_BORDER_COLOR)
}

wave_editor :: proc(wave: ^Wave, bounds: rl.Rectangle, cycle_width: f32 = 1.0, amplitutde_scale: f32 = 1.0) {
    GAP :: 10.0
    
    controls_width := 2 * bounds.height
    controls_left_width := (2.0/3.0) * controls_width
    controls_right_width := controls_width - controls_left_width - GAP
    left_controls_height := bounds.height/2 - GAP/2 - UI_LABEL_FONT_SIZE

    rl.DrawText("Frequency", auto_cast bounds.x, auto_cast bounds.y, UI_LABEL_FONT_SIZE, UI_FOREGROUND_COLOR)
    number_scroll_input(
        rl.Rectangle{ 
            bounds.x, 
            bounds.y + auto_cast UI_LABEL_FONT_SIZE, 
            controls_left_width, 
            left_controls_height }, 
        &wave.frequency)

    rl.DrawText("Amplitude", auto_cast bounds.x, auto_cast (bounds.y + GAP + left_controls_height) + UI_LABEL_FONT_SIZE, UI_LABEL_FONT_SIZE, UI_FOREGROUND_COLOR)
    number_scroll_input(
        rl.Rectangle{ 
            bounds.x, 
            bounds.y + auto_cast 2 * UI_LABEL_FONT_SIZE + GAP + left_controls_height, 
            controls_left_width, 
            left_controls_height }, 
        &wave.amplitutde)
    
    rl.DrawText("Phase", auto_cast (bounds.x + controls_left_width + GAP), auto_cast bounds.y, UI_LABEL_FONT_SIZE, UI_FOREGROUND_COLOR)
    angle_scroll_input(rl.Vector2{ bounds.x + controls_left_width + GAP, bounds.y + UI_LABEL_FONT_SIZE }, controls_right_width, &wave.phase)
    phase_text := rl.TextFormat("%.2f rad", wave.phase)
    rl.DrawText(
        phase_text, 
        auto_cast (bounds.x + controls_left_width + GAP + controls_right_width/2 - auto_cast rl.MeasureText(phase_text, UI_LABEL_FONT_SIZE)/2), 
        auto_cast (bounds.y + UI_LABEL_FONT_SIZE + 5 + controls_right_width), 
        UI_LABEL_FONT_SIZE, UI_FOREGROUND_COLOR)
    
    HUE_BAR_WIDTH :: 10
    wave_bounds := bounds
    wave_bounds.x += controls_width + GAP
    wave_bounds.width -= controls_width + 2*GAP + HUE_BAR_WIDTH
    color := rl.ColorFromHSV(wave.hue, 1.0, 1.0)
    draw_wave(wave_bounds, sample_wave, wave, color, cycle_width, amplitutde_scale)

    hue_bar_rect := rl.Rectangle{ wave_bounds.x + wave_bounds.width + GAP, bounds.y, HUE_BAR_WIDTH, bounds.height }
    hover_rect := hue_bar_rect
    HOVER_MARGIN :: 5
    hover_rect.x -= HOVER_MARGIN
    hover_rect.width += 2*HOVER_MARGIN
    if rl.CheckCollisionPointRec(rl.GetMousePosition(), hover_rect) {
        rl.GuiColorBarHue(hue_bar_rect, "", &wave.hue)
    } else {
        rl.DrawRectangleRec(hue_bar_rect, color)
        rl.DrawRectangleLinesEx(hue_bar_rect, 1.0, UI_BORDER_COLOR)
    }
}

delete_button :: proc(bounds: rl.Rectangle) -> bool {
    X_PADDING :: 10
    X_THICK :: 3
    X_COLOR :: rl.RED
    x_size := min(bounds.width, bounds.height) - 2*X_PADDING
    button_res := button(bounds, "")
    rl.DrawLineEx(
        { bounds.x + bounds.width/2 - x_size/2, bounds.y + bounds.height/2 - x_size/2 }, 
        { bounds.x + bounds.width/2 + x_size/2, bounds.y + bounds.height/2 + x_size/2 }, 
        X_THICK, X_COLOR)
    rl.DrawLineEx(
        { bounds.x + bounds.width/2 + x_size/2, bounds.y + bounds.height/2 - x_size/2 }, 
        { bounds.x + bounds.width/2 - x_size/2, bounds.y + bounds.height/2 + x_size/2 }, 
        X_THICK, X_COLOR)
    return button_res
}

main :: proc() {
    rl.InitWindow(800, 600, "Wave Adder")
    defer rl.CloseWindow()

    rl.SetWindowState(rl.ConfigFlags{.WINDOW_RESIZABLE, .WINDOW_ALWAYS_RUN})

    default_wave := Wave{
        amplitutde=10,
        frequency=200,
        phase=0,
    }
    waves: [dynamic]Wave = {}
    // square wave
    freq: f32 = 50.0
    amp: f32 = 40
    for i in 0..<10 {
        append(&waves, Wave{
            frequency = freq * (auto_cast i*2.0 + 1),
            amplitutde = amp / (auto_cast i*2.0 + 1),
            phase = 0.0,
        })
    }

    scroll_offset: f32 = 0.0
    for !rl.WindowShouldClose() {
        width := cast(f32) rl.GetRenderWidth()
        height := cast(f32) rl.GetRenderHeight()
        mouse := rl.GetMousePosition()
        PADDING :: 10
        
        rl.BeginDrawing()
        
        rl.ClearBackground(BACKGROUND_COLOR)
        
        TOP_BAR_HEIGHT :: 40
        if button({ PADDING, PADDING, 150, TOP_BAR_HEIGHT }, "+ Wave") {
            append(&waves, default_wave)
        }

        WAVE_HEIGHT :: 100.0
        SCROLL_BAR_WIDTH :: 20
        waves_rect_top : f32 = 2*PADDING + TOP_BAR_HEIGHT
        waves_rect_height := height - TOP_BAR_HEIGHT - 4*PADDING - WAVE_HEIGHT
        waves_rect := rl.Rectangle{ PADDING, waves_rect_top, auto_cast width - 2*PADDING, waves_rect_height }
        push_scissor(waves_rect)
        for &wave, i in waves {
            DELETE_BUTTON_WIDTH :: 30
            wave_rect := rl.Rectangle{ PADDING, waves_rect_top + auto_cast i*(WAVE_HEIGHT + PADDING) - scroll_offset, width - 4*PADDING - DELETE_BUTTON_WIDTH - SCROLL_BAR_WIDTH, WAVE_HEIGHT }
            wave_editor(&wave, wave_rect, 10000)
            delete_rect := rl.Rectangle{ 
                wave_rect.x + wave_rect.width + PADDING, wave_rect.y, 
                DELETE_BUTTON_WIDTH, wave_rect.height 
            }
            if delete_button(delete_rect) {
                // NOTE: Normally you shouldn't remove an element while iterating but this works just fine for some reason
                ordered_remove(&waves, i)
            }
        }
        pop_scissor()

        total_waves_height: f32 = (WAVE_HEIGHT + PADDING) * auto_cast len(waves)
        if rl.CheckCollisionPointRec(mouse, waves_rect) {
            scroll_offset -= 10 * rl.GetMouseWheelMove()
            scroll_offset = clamp(scroll_offset, 0, total_waves_height - waves_rect_height)
        }
        verticle_scroll_bar({ width - PADDING - SCROLL_BAR_WIDTH, waves_rect_top, SCROLL_BAR_WIDTH, waves_rect_height }, total_waves_height, &scroll_offset)

        waves_slice := waves[:]
        draw_wave({ PADDING, height - PADDING - WAVE_HEIGHT, width - 2*PADDING, WAVE_HEIGHT }, sample_waves_sum, &waves_slice, rl.WHITE, 10000)
        
        rl.EndDrawing()
    }
}
