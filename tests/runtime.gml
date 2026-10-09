global.qa_results = [];
function qa_check(condition, label) {
    array_push(global.qa_results, { test: label, passed: condition });
}
qa_check(variable_global_exists("qol"), "QoL feature loaded");
if (variable_global_exists("qol")) {
    global.qol_hold_time = 0;
    global.qol_next_click = global.qol.hold_delay;
    qa_check(!qol_repeat_tick(true, true, true, 1/60), "initial press does not double click");
    var repeats = 0;
    repeat (60) if (qol_repeat_tick(true, false, true, 1/60)) repeats++;
    qa_check(repeats >= 12 && repeats <= 13, "long hold produces about 15 clicks/sec after delay");
    qa_check(!qol_repeat_tick(false, false, true, 1/60), "release stops immediately");
    qa_check(global.qol_hold_time == 0, "release clears hold timer");
    repeat (20) qol_repeat_tick(true, false, true, 1/60);
    qa_check(!qol_repeat_tick(true, false, false, 1/60), "focus loss stops immediately");
    qa_check(global.qol_hold_time == 0, "focus loss clears hold timer");
    var short_repeat = false;
    qol_repeat_tick(true, true, true, 1/60);
    repeat (5) short_repeat = short_repeat || qol_repeat_tick(true, false, true, 1/60);
    qa_check(!short_repeat, "short tap stays a single click");
    qol_repeat_tick(false, false, true, 1/60);
    var low_fps = 0;
    qol_repeat_tick(true, true, true, 1/30);
    repeat (30) if (qol_repeat_tick(true, false, true, 1/30)) low_fps++;
    qa_check(low_fps >= 12 && low_fps <= 13, "repeat frequency stable at 30 fps");
    qol_repeat_tick(false, false, true, 1/60);
    qol_repeat_tick(true, true, true, 1/60);
    qa_check(qol_repeat_tick(true, false, true, 5) == false, "long frame does not burst clicks");
    qa_check(qol_frames(60) == 20, "animation delay shortened threefold");
    qa_check(qol_frames(1) == 1, "minimum alarm is one frame");
    qa_check(qol_lerp_rate(0.1, 100) == 1, "high upgrades cannot overshoot interpolation");
    // GML has a comparison epsilon: <= also accepts equality within that epsilon.
    qa_check(abs(qol_lerp_rate(0.1) - 0.3) <= 0.00001, "animation interpolation accelerated");
    global.qa_results[array_length(global.qa_results)-1].actual = qol_lerp_rate(0.1);
    global.qa_results[array_length(global.qa_results)-1].explicit = qol_lerp_rate(0.1, 1);
}
var qa_handle = file_text_open_write(working_directory + "qol_test_results.json");
file_text_write_string(qa_handle, json_stringify(global.qa_results));
file_text_close(qa_handle);
game_end();
