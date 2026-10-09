using System;
using System.IO;
using UndertaleModLib.Compiler;
var root=Environment.GetEnvironmentVariable("CTP_TESTS_DIR") ?? throw new Exception("Set CTP_TESTS_DIR");
var imports=new CodeImportGroup(Data);
imports.QueueAppend("gml_GlobalScript_scrFiles",File.ReadAllText(Path.Combine(root,"runtime.gml")));
var result=imports.Import();
if(!result.Successful)throw new Exception(result.PrintAllErrors(true));
