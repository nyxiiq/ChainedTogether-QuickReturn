# ChainedTogether QuickReturn

[简体中文](#简体中文) | [English](#english)

## 简体中文

为《Chained Together》提供默认 **F6 返回最高点**快捷键的 UE4SS Lua Mod。

当前源码版本 **v0.1.5**。2026-11-07 玩家已实际验证 F6 能返回最高点，日志同时确认原生救援事件和后续救援执行。菜单拦截及三秒冷却拒绝也有实测记录。

## 功能

- 不打开 Esc 菜单，直接请求游戏原生的返回最高点流程。
- 使用游戏查询得到的最高点，沿用原生效果、延时和救援处理。
- 保留原生模式、车辆、有效最高点、权限等限制；本 Mod 额外限定自己创建且只有一位本地玩家的房间。
- 菜单、文本焦点、切图、初始化和冷却保护；API 异常后本次游戏进程停用快捷键，避免自动重试。

不包含游戏源码、解包资产、存档、坐标数据、UE4SS DLL 或第三方分析工具。仓库只提供我们编写的 Lua Mod 与说明。

## 已验证环境

| 项目 | 版本 |
|---|---|
| 游戏 Steam BuildID | 26273336 |
| Unreal Engine | 5.3.2 |
| UE4SS | 3.0.1 |
| Mod | 0.1.5 |

游戏或框架更新后需重新验证兼容性。当前脚本会拒绝不同的 UE4SS 版本。

## 安装

1. 完全退出游戏。
2. 从 [UE4SS 官方发行页面](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/v3.0.1) 获取 UE4SS 3.0.1，按其说明安装到游戏的 `ChainedTogether/Binaries/Win64` 目录。本仓库不附带框架。
3. 把本仓库 `Mods/QuickReturnHighestPoint` 文件夹复制到该目录的 `Mods` 中。
4. 先备份已有 `Mods/mods.txt`，再添加或更新这一行，保留其他 Mod 的配置：

   ```text
   QuickReturnHighestPoint : 1
   ```

5. 启动游戏，在自己创建且只有一人的关卡中验证。

不要用配置示例覆盖已有 mods.txt，也不要在游戏运行时替换 Lua 文件。

## 使用

在原生功能允许返回最高点的模式中，关闭菜单、结束文本输入，保持游戏窗口聚焦，轻按 **F6**。原生流程包含约一秒延时。请求之间有三秒冷却。

本版尚无按键设置界面；F6 通过 `RegisterKeyBind(Key.F6, key_pressed)` 注册。原生设置菜单集成属于后续工作。若 F6 已被其他 Mod 注册，本 Mod 会停止注册而不覆盖它。

## 可选诊断 Mod

`optional/QuickReturnTrace` 是我们编写的四个定向 Blueprint Hook，仅记录按钮、查询、救援请求和救援执行，不调用传送，不修改参数。排查问题时可将其复制到游戏 `Mods` 下，并添加：

```text
QuickReturnTrace : 1
```

每个目标每次启动最多记录 16 次，超出后无日志不代表事件没有执行。正常使用不依赖此诊断 Mod。

## 卸载与恢复

退出游戏，在 `Mods/mods.txt` 中将 `QuickReturnHighestPoint : 1` 改为 `QuickReturnHighestPoint : 0` 即可停用。需要删除时，仅删除 `Mods/QuickReturnHighestPoint` 文件夹；若安装了可选 Trace，同样停用并仅删除它的文件夹。

保留其他 Mod 配置。此 Mod 的安装/卸载不需要修改游戏 PAK、EXE 或存档。UE4SS 框架自身的卸载请遵循其官方说明，以免影响其他 Mod。

## 实现说明

输入事件经 UE4SS 转交游戏线程；每次解析当前本地控制器、GameState 和最高点对象，检查条件后调用游戏的 `GS_Game.RescueEvent`。空对象参数使用经过有效性及零地址检查的 UObject 包装，以兼容 UE4SS 3.0.1 的参数桥接。

关键修正是：不能以稍后的 `PlayerController.IsInputKeyDown` 结果否定 UE4SS 已收到的按键事件。现场测试中，短按和长按的首次采样都可能为 false，导致此前版本在调用传送前提前退出。v0.1.5 移除了这个二次门槛，保留其他保护后完成实际返回验收。

没有模拟鼠标点击，也没有直接写角色位置或自行计算最高点坐标。代码中的资源路径和函数标识用于引用游戏运行时对象；不包含其实现或资产。

## 验证范围与已知限制

- 单次 F6 实际返回已由玩家验证，并有原生查询、请求及延时救援日志支持。
- 菜单阻断及冷却拒绝已实测。玩家报告长按无可见重复，但缺少物理按下/松开时刻与所有回调的对应，尚不能保证任意时长长按都只发一次请求。
- 文本焦点与切图保护有代码和模拟测试，尚未完成全部游戏内边界验收。
- UE4SS 调试窗口聚焦时也可能触发按键回调；本版尚未完善这项焦点保护。请保持游戏窗口聚焦使用。
- 不支持加入其他玩家的房间，不支持多人功能。
- 本地开发阶段曾通过 71 项模拟测试、873 个断言；这些测试不能替代实际游戏验证。本仓库未打包测试运行器、第三方依赖或带游戏资产的研究目录。

本项目为非官方 Mod，与游戏开发商或 UE4SS 项目无隶属关系。UE4SS 依赖由其自身许可证约束。

---

## English

A UE4SS Lua Mod for **Chained Together** that binds **F6** to the game's native return-to-highest-point feature.

Current source version: **v0.1.5**. On November 7, 2026, a player confirmed that F6 successfully returned their character to the highest point. Runtime logs also confirmed the native rescue request and its subsequent execution. Menu blocking and the three-second cooldown were tested in game.

### Features

- Requests the game's native return flow without opening the Esc menu.
- Uses the highest point reported by the game and preserves native effects, delay, and rescue behavior.
- Retains native restrictions, including game mode, vehicles, valid rescue points, and authority checks. The Mod additionally requires a self-hosted session with exactly one local player.
- Includes guards for menus, text focus, map transitions, initialization, and cooldown. An API error disables the hotkey for the current game process to prevent automatic retries.

This repository contains our Lua Mod code and documentation. It does not include game source code, extracted assets, saves, coordinate data, UE4SS DLLs, or third-party analysis tools.

### Tested environment

| Component | Version |
|---|---|
| Game Steam BuildID | 26273336 |
| Unreal Engine | 5.3.2 |
| UE4SS | 3.0.1 |
| Mod | 0.1.5 |

Compatibility must be revalidated after game or framework updates. The current script rejects UE4SS versions other than 3.0.1.

### Installation

1. Exit the game completely.
2. Obtain UE4SS 3.0.1 from the [official release page](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/v3.0.1) and follow its instructions to install it in the game's `ChainedTogether/Binaries/Win64` directory. The framework is not bundled here.
3. Copy this repository's `Mods/QuickReturnHighestPoint` folder into the `Mods` folder in that directory.
4. Back up your existing `Mods/mods.txt`, then add or update the following line while preserving all other Mod entries:

   ```text
   QuickReturnHighestPoint : 1
   ```

5. Launch the game and test in a session you host with no other players.

Merge the configuration example into your existing mods.txt; do not overwrite the file. Replace Lua files only while the game is closed.

### Usage

Select a mode where the native highest-point return feature is available. Close menus, finish text input, keep the game window focused, and briefly press **F6**. The native flow includes a delay of approximately one second. Requests have a three-second cooldown.

This version has no key-binding settings interface. F6 is registered through `RegisterKeyBind(Key.F6, key_pressed)`; integration with the native settings menu is future work. If another Mod has already registered F6, this Mod stops registration rather than replacing that binding.

### Optional diagnostic Mod

`optional/QuickReturnTrace` contains four targeted Blueprint hooks written for this project. It only logs the native button, query, rescue request, and rescue execution. It does not request teleportation or modify parameters. To use it for troubleshooting, copy the folder into the game's `Mods` directory and add:

```text
QuickReturnTrace : 1
```

Each target logs up to 16 hits per game launch. Once that limit is reached, missing log entries do not mean that events stopped executing. Normal use does not require this diagnostic Mod.

### Uninstallation and recovery

Exit the game and change `QuickReturnHighestPoint : 1` to `QuickReturnHighestPoint : 0` in `Mods/mods.txt` to disable it. To remove its files, delete only the `Mods/QuickReturnHighestPoint` folder. If you installed the optional Trace Mod, disable its entry and remove only its own folder as well.

Preserve all other Mod settings. Installing or removing this Mod does not require changes to the game's PAK files, executable, or saves. Follow the framework's own instructions if you also want to uninstall UE4SS, which may be required by other Mods.

### Implementation notes

UE4SS passes the input event to the game thread. For each request, the script resolves the current local controller, GameState, and highest-point object, checks the required conditions, and invokes the game's `GS_Game.RescueEvent`. Null object arguments use a UObject wrapper verified to be invalid and have address zero, for compatibility with UE4SS 3.0.1's parameter bridge.

The key fix in v0.1.5 removes a second input gate: a later `PlayerController.IsInputKeyDown` sample cannot reliably validate an event that UE4SS has already received. During testing, the initial game-side sample could be false for both brief and held presses, causing previous versions to exit before requesting teleportation. Removing this gate while retaining the other guards enabled the first successful in-game return.

The Mod does not simulate mouse clicks, write character positions directly, or calculate highest-point coordinates. Asset paths and function identifiers in the code refer to game runtime objects; their implementations and assets are not included.

### Validation and known limitations

- A single F6 return was confirmed by the player and supported by logs of the native query, request, and delayed rescue execution.
- Menu blocking and cooldown rejection were tested in game. The player reported no visible repeated teleportation while holding F6, but physical key-down/key-up times were not correlated with every callback. Exactly one request for an arbitrarily long hold is not guaranteed.
- Text-focus and map-transition guards have code and mock-test coverage; all in-game edge cases have not yet been validated.
- UE4SS may also dispatch hotkeys while its debug window is focused. This focus boundary is not fully guarded in this version. Keep the game window focused when using the hotkey.
- Joining another player's session and multiplayer use are not supported.
- Local development checks passed 71 mock tests with 873 assertions. These do not replace in-game validation. Test runners, third-party dependencies, and research directories containing game assets are not bundled in this repository.

This is an unofficial Mod and is not affiliated with the game's developers or the UE4SS project. UE4SS is governed by its own license.
