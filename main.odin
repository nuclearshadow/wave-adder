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
    return rl.IsMouseButtonReleased(.LEFT) && is_hovering
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
    rl.BeginScissorMode(
        auto_cast bounds.x, 
        auto_cast bounds.y, 
        auto_cast bounds.width, 
        auto_cast bounds.height)
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
    rl.EndScissorMode()
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

main :: proc() {
    rl.InitWindow(800, 600, "Wave Adder")
    defer rl.CloseWindow()

    rl.SetWindowState(rl.ConfigFlags{.WINDOW_RESIZABLE, .WINDOW_ALWAYS_RUN})

    default_wave := Wave{
        amplitutde=10,
        frequency=200,
        phase=0,
    }
    // waves := [?]Wave{ 0..<3 = default_wave }
    waves: [dynamic]Wave = {default_wave}

    for !rl.WindowShouldClose() {
        width := cast(f32) rl.GetRenderWidth()
        height := cast(f32) rl.GetRenderHeight()
        PADDING :: 10
        
        rl.BeginDrawing()
        
        rl.ClearBackground(BACKGROUND_COLOR)
        
        TOP_BAR_HEIGHT :: 40
        if button({ PADDING, PADDING, 150, TOP_BAR_HEIGHT }, "+ Wave") {
            append(&waves, default_wave)
        }

        WAVE_HEIGHT :: 100.0
        for &wave, i in waves {
            wave_editor(&wave, rl.Rectangle{ PADDING, 2*PADDING + TOP_BAR_HEIGHT + auto_cast i*(WAVE_HEIGHT + PADDING), width - 2*PADDING, WAVE_HEIGHT }, 10000)
        }

        waves_slice := waves[:]
        draw_wave(rl.Rectangle{ PADDING, height - PADDING - WAVE_HEIGHT, width - 2*PADDING, WAVE_HEIGHT }, sample_waves_sum, &waves_slice, rl.WHITE, 10000)
        
        rl.EndDrawing()
    }
}
