// Visual speed and physical left-button repeat; independent of economy timers.
global.qol = { animation_speed: 3, clicks_per_second: 15, hold_delay: 0.2 };
if (file_exists("qol_settings.json")) {
    try {
        var qol_config = json_load("qol_settings.json");
        if (is_struct(qol_config)) {
            if (variable_struct_exists(qol_config, "animation_speed") && is_real(qol_config.animation_speed))
                global.qol.animation_speed = clamp(qol_config.animation_speed, 1, 6);
            if (variable_struct_exists(qol_config, "clicks_per_second") && is_real(qol_config.clicks_per_second))
                global.qol.clicks_per_second = clamp(qol_config.clicks_per_second, 1, 30);
            if (variable_struct_exists(qol_config, "hold_delay") && is_real(qol_config.hold_delay))
                global.qol.hold_delay = clamp(qol_config.hold_delay, 0.1, 1);
        }
    } catch (qol_error) {
        // A malformed optional config must not stop the game from starting.
    }
}
global.qol_hold_time = 0;
global.qol_next_click = global.qol.hold_delay;
global.qol_repeat = false;

function qol_repeat_tick(down, pressed, focused, elapsed) {
    if (!down || !focused || pressed) {
        global.qol_hold_time = 0;
        global.qol_next_click = global.qol.hold_delay;
        return false;
    }
    // Never turn a stalled frame into a backlog of clicks.
    global.qol_hold_time += clamp(elapsed, 0, 0.1);
    if (global.qol_hold_time + 0.000001 < global.qol_next_click)
        return false;
    var interval = 1 / global.qol.clicks_per_second;
    global.qol_next_click += interval;
    if (global.qol_next_click <= global.qol_hold_time)
        global.qol_next_click = global.qol_hold_time + interval;
    return true;
}

function qol_frames(frames) {
    return max(1, ceil(frames / global.qol.animation_speed));
}

function qol_lerp_rate(base_rate, multiplier = 1) {
    return clamp(base_rate * multiplier * global.qol.animation_speed, 0, 1);
}
