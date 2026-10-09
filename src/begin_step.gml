global.qol_repeat = qol_repeat_tick(mouse_check_button(mb_left),
    mouse_check_button_pressed(mb_left), window_has_focus(), delta_time / 1000000);
if (global.qol_repeat) {
    global.game_stats.stats.nb_clicks++;
    cursor_scale = 2;
}
