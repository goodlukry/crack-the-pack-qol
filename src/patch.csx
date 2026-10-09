using System;
using System.IO;
using UndertaleModLib.Compiler;
using UndertaleModLib.Decompiler;
using UndertaleModLib.Models;

var root = Environment.GetEnvironmentVariable("CTP_BUILD_DIR") ?? throw new Exception("Set CTP_BUILD_DIR before running this script");
var context = new GlobalDecompileContext(Data);
var imports = new CodeImportGroup(Data);
int changes = 0;
void Edit(string name, Func<string, string> edit) {
    var code = Data.Code.ByName(name);
    if (code == null) throw new Exception("Missing code: " + name);
    string before = GetDecompiledText(code, context);
    string after = edit(before);
    if (before == after) throw new Exception("No change: " + name);
    imports.QueueReplace(code, after);
    changes++;
}
string ReplaceRequired(string text, string before, string after) {
    if (!text.Contains(before)) throw new Exception("Missing patch anchor: " + before);
    return text.Replace(before, after);
}
imports.QueueAppend("gml_GlobalScript_scrFiles", File.ReadAllText(Path.Combine(root, "qol.gml")));
var controller = Data.GameObjects.ByName("oGame");
var beginStep = controller.EventHandlerFor(EventType.Step, (uint)1, Data);
imports.QueueReplace(beginStep, File.ReadAllText(Path.Combine(root, "begin_step.gml")));
Edit("gml_Object_oGame_Create_0", s => s + "\nglobal.qol_repeat = false;\nglobal.qol_hold_time = 0;\nglobal.qol_next_click = global.qol.hold_delay;\n");
Edit("gml_GlobalScript_scrUtils", s => ReplaceRequired(s,
    "var is_click = mouse_check_button_pressed(mb_left) || oGame.mouse_click;",
    "var is_click = mouse_check_button_pressed(mb_left) || oGame.mouse_click || global.qol_repeat;"));
Edit("gml_GlobalScript_scrCard", s => ReplaceRequired(s, "card.alarm[0] = arg1;", "card.alarm[0] = qol_frames(arg1);"));
Edit("gml_Object_oOpeningCard2_Create_0", s => ReplaceRequired(s,
    "alarm[0] = room_height - ystart;", "alarm[0] = qol_frames(room_height - ystart);"));
Edit("gml_Object_oOpeningCard2_Step_0", s => {
    s = ReplaceRequired(s, "if (side_from != side_to)", "mult *= global.qol.animation_speed;\nif (side_from != side_to)");
    s = ReplaceRequired(s, "0.1 * mult", "clamp(0.1 * mult, 0, 1)");
    s = ReplaceRequired(s, "0.1 + (mult / 10)", "clamp(0.1 + (mult / 10), 0, 1)");
    s = ReplaceRequired(s, ", 0.2);", ", qol_lerp_rate(0.2));");
    return s;
});
Edit("gml_Object_oOpeningCard2_Alarm_1", s => {
    s = ReplaceRequired(s, "var is_clone =", "mult *= global.qol.animation_speed;\nvar is_clone =");
    s = ReplaceRequired(s, "var duration = clamp(type / 1.5, 2, 5);", "var duration = clamp(type / 1.5, 2, 5) / global.qol.animation_speed;");
    s = ReplaceRequired(s, "duration += 1;", "duration += 1 / global.qol.animation_speed;");
    return s;
});
Edit("gml_Object_oOpeningCard2_Other_10", s => ReplaceRequired(s,
    "alarm[3] = 1 + random(10);", "alarm[3] = qol_frames(1 + random(10));"));
Edit("gml_Object_oOpeningCard2_Alarm_3", s => ReplaceRequired(s,
    "call_later(5, time_source_units_frames", "call_later(qol_frames(5), time_source_units_frames"));
Edit("gml_Object_oOpeningBooster_Step_0", s => ReplaceRequired(s, ", 0.1);", ", qol_lerp_rate(0.1));"));
var result = imports.Import();
if (!result.Successful) throw new Exception(result.PrintAllErrors(true));
Directory.CreateDirectory(Path.Combine(root, "verification"));
var outputContext = new GlobalDecompileContext(Data);
foreach (var name in new[] {
    "gml_GlobalScript_scrFiles", "gml_GlobalScript_scrUtils", "gml_GlobalScript_scrCard",
    "gml_Object_oGame_Step_1", "gml_Object_oGame_Create_0", "gml_Object_oOpeningCard2_Step_0",
    "gml_Object_oOpeningCard2_Alarm_1", "gml_Object_oOpeningBooster_Step_0"
}) {
    File.WriteAllText(Path.Combine(root, "verification", name + ".gml"),
        GetDecompiledText(Data.Code.ByName(name), outputContext));
}
var beginEvent = controller.Events[(int)EventType.Step];
if (!System.Linq.Enumerable.Any(beginEvent, e => e.EventSubtype == 1 && e.Actions.Count > 0))
    throw new Exception("Begin Step event was not linked");
Console.WriteLine("QoL patch imported; " + changes + " existing code entries changed; Begin Step linked.");
