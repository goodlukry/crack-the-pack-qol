# 开包狂潮 / Crack the Pack 动画加速与长按连点

非官方便捷补丁 v1.1.0。可单独安装在匹配版本的原版游戏上，也可装在本项目汉化版上。

- 开包卡牌入场、翻面和新卡展示约3倍速。
- 鼠标左键长按0.2秒后，以每秒约15次重复点击作用于鼠标所在位置。
- 短按保留一次点击；松开鼠标或游戏失焦后停止连点。
- 原有升级和游戏经济计时保持原样。

## 使用

1. 从仓库 Releases 下载 `crack-the-pack-qol-v1.1.0.zip` 并解压。
2. 正常退出游戏，双击 `Install.cmd`，选择包含 `CrackThePack.exe` 和 `data.win` 的 `game` 文件夹。
3. 重新启动游戏。
4. 恢复时先退出游戏，再双击 `Restore.cmd` 并选择同一游戏目录。

备份目录为 `QoLBackup_OSS_v1`。已有配置文件会保留；安装和恢复均不写入个人存档。

## 调整速度

编辑游戏目录的 `qol_settings.json`，保存后重新启动：

| 字段 | 含义 | 默认值 | 范围 |
| --- | --- | --- | --- |
| `animation_speed` | 动画倍速 | 3 | 1–6 |
| `clicks_per_second` | 每秒连点次数 | 15 | 1–30 |
| `hold_delay` | 开始连点前长按秒数 | 0.2 | 0.1–1 |

游戏自带的钱包初始资金上限为100。到达100后，在“升级”页花100购买“钱包”，上限提高至1000。
此补丁不取消钱包容量限制。

## 安装顺序与适配版本

同时使用汉化和加速时，先装汉化，再装加速。恢复时先恢复加速，再恢复汉化。
已在原版上安装加速后，要增加汉化，先恢复加速，再按上述顺序安装。
v1.0本地制作版用户若已加速，先使用原来的恢复脚本还原加速，再安装本汉化发布版。

安装器核对 SHA-256。版本不匹配、差分损坏或备份不一致时停止，不覆盖后续补丁。

| 支持的安装基线 | data.win SHA-256 |
| --- | --- |
| 原版 | `dea7c94ad726f85403361b40d40c71c0e2f08b5c73de65ef50240c63f3bac449` |
| 开源汉化 v1.1.0 | `f71289b09b48120b8f454a81eb57e2f54e1a11a924ce762b19a9e7f9820cc244` |
| 本地汉化 v1.0 | `1d0ada57f7c6c5e1633ed3092ad38cceb73dc1590dbeec2ffe5dac1ef9bfe7bb` |

## 源码与构建

源码按 MIT 许可开放，第三方材料见 `THIRD_PARTY_NOTICES.md`。仓库不附带游戏本体或个人存档。
安装发布包只需 Windows PowerShell 5.1/.NET，不需要 Python 或 UndertaleModTool。
从源码构建需要 Python 3.13 和单独获取的 [UndertaleModTool CLI v0.9.2.0](https://github.com/UnderminersTeam/UndertaleModTool/releases/tag/0.9.2.0)。

加速补丁从 `manifest.json` 所列的任一未加速基线构建。构建前不要选已经应用加速补丁的 `data.win`。
逻辑源文件为 `src/qol.gml` 与 `src/begin_step.gml`；`src/patch.csx` 连接输入和动画事件。

```powershell
python tools/build.py --game-dir '你的game目录' --utmt 'UndertaleModCli.exe的路径'
# 可选：--data-file '原版或指定基线data.win的路径'
```

生成文件只保存在 `_local/build/`，不直接安装到游戏；`build_result.json` 提供基线、目标和差分文件的哈希。
修改后重新构建时，更新 `patches/` 的差分、`manifest.json` 的对应哈希，以及配套资产的哈希。
CTPDIFF1 差分格式由 `tools/make_delta.py` 编码，Windows安装器使用 `PatchCore.ps1` 解码。

## 检查

```powershell
python -m unittest discover -s tests -v
```

自动检查差分还原、文件损坏、版本不匹配、安装与恢复、重复安装、既有配置保留和后续补丁保护。
CI包含 Windows 与 Linux；Linux只运行与平台无关的差分测试。游戏画面和手感不属于这套CI的验证范围。

`tests/runtime.gml` 记录14项GameMaker运行器断言，结果见 `tests/runtime_results.json`；这些结果来自此前的本地汉化基线。
如需重跑，设置 `CTP_TESTS_DIR` 为 `tests` 的绝对路径，使用CLI将 `tools/runtime_tests.csx` 追加到刚构建的 `data.win`，
输出到独立的临时游戏目录，再使用用户自备的运行器启动。测试会写出 `qol_test_results.json` 后退出；不要在正式游戏目录使用测试版data.win。
