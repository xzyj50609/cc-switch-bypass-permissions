# 终于查明白了：CC Switch 打开的 Claude Code 为什么一直不是完全访问模式

**Fix CC Switch launching Claude Code without bypassPermissions on Windows**

**日期**：2026-06-13 | **平台**：Windows | **工具**：CC Switch + Claude Code CLI

---

## 目录

- [这个仓库解决什么问题](#这个仓库解决什么问题)
- [典型症状](#典型症状)
- [一句话根因](#一句话根因)
- [快速判断是否是同一问题](#快速判断是否是同一问题)
- [完整排查过程](#完整排查过程)
- [修复方案](#修复方案)
  - [一键安装脚本](#一键安装脚本（推荐）)
  - [手动修复步骤](#手动修复步骤)
- [如何验证修复成功](#如何验证修复成功)
- [如何回滚](#如何回滚)
- [复发判断](#如何判断是否复发)
- [排查教训](#这次排查的几个教训)
- [打赏](#打赏)

---

## 这个仓库解决什么问题

CC Switch 是一个流行的 Claude Code 供应商切换工具。它可以让你在同一台机器上快速切换不同的 API 供应商（不同 base url / auth token）。

但在 Windows 上，**从 CC Switch 打开的 Claude Code 终端总是 `permissionMode=default`，不是完全访问模式（`bypassPermissions`）**——即使你在 `~/.claude/settings.json` 里已经设置了相关字段，也没有用。

这个仓库提供：

1. 完整的排查过程记录（含关键误导点和翻转时刻）
2. 可直接运行的一键修复脚本
3. 回滚方法

---

## 典型症状

手动在普通终端输入：

```cmd
claude --dangerously-skip-permissions
```

能进入完全访问模式。

但从 CC Switch 的"终端"按钮打开后，Claude 会话里：

```text
permissionMode=default
```

而不是：

```json
{"type":"permission-mode","permissionMode":"bypassPermissions"}
```

更迷惑的是：进入 Claude 后再跑 `where claude`，第一条可能已经是你自己放的 wrapper，看起来一切正常——但实际上权限没变。

---

## 一句话根因

CC Switch 启动 Claude 时生成一个临时 `.bat`，内容是裸的：

```cmd
claude --settings "<临时配置.json>"
```

这个 `.bat` 是在 **CC Switch 自己的进程环境**里执行的，用的是 CC Switch 启动时继承的旧 PATH。  
旧 PATH 里更靠前的是 npm 的 shim：

```text
%APPDATA%\npm\claude.cmd
```

而不是你放在别处的 wrapper。  
所以哪怕你在 `.cc-switch\bin` 里放了 wrapper、哪怕进 Claude 后 `where claude` 显示 wrapper 排第一，**启动那一刻走的仍然是 npm shim**。

解决方法：**直接接管 npm shim**。

---

## 快速判断是否是同一问题

**1. 看 wrapper 日志**

如果你之前已经在 `.cc-switch\bin` 里放过 wrapper，看日志：

```cmd
type "%USERPROFILE%\.cc-switch\logs\claude-wrapper.log"
```

如果从 CC Switch 打开 Claude 后日志没有新的 `wrapper-invoked` 记录，说明 wrapper 没被启动——就是这个问题。

**2. 看最新临时 settings 是否被 patch**

CC Switch 生成的临时文件：

```text
%TEMP%\claude_<provider-id>_<pid>.json
```

如果打开后只有：

```json
{ "env": { ... } }
```

没有 `skipDangerousModePermissionPrompt` 和 `permissions.defaultMode`，说明 patcher 没跑。

**3. 看最新 Claude 会话权限模式**

最新会话文件在：

```text
%USERPROFILE%\.claude\projects\<项目路径hash>\<session-id>.jsonl
```

搜索 `permissionMode`，如果是 `default` 而不是 `bypassPermissions`，问题确认。

---

## 完整排查过程

### 1. 初始症状：找不到 `claude` 命令

CC Switch 打开的终端报：

```text
'claude' 不是内部或外部命令，也不是可运行的程序或批处理文件。
```

原因：CC Switch 会为每个 provider 写一份临时 settings，可以通过 `env` 字段注入环境变量。但如果 provider 的 `env` 里没有 `PATH/PATHEXT`，终端找不到 `claude`。

**修法**：在 CC Switch 的 provider 配置和公共配置里补上完整的 `PATH` 和 `PATHEXT`。这一步解决了"能不能打开"的问题，但没有解决"是不是完全访问模式"。

---

### 2. 第一版 wrapper：放在 `.cc-switch\bin`

创建：

```text
%USERPROFILE%\.cc-switch\bin\claude.cmd
```

让 CC Switch 执行 `claude --settings ...` 时自动补 `--dangerously-skip-permissions`。

并把 `%USERPROFILE%\.cc-switch\bin` 加到 provider 的 `env.PATH` 最前面。

进 Claude 后：

```cmd
where claude
```

第一条确实变成了 `.cc-switch\bin\claude.cmd`。看起来应该成功了。

但会话日志里仍然是 `permissionMode=default`。

---

### 3. 阅读 CC Switch 源码，找到真实启动模板

浅克隆 CC Switch 源码：

```cmd
git clone --depth 1 https://github.com/farion1231/cc-switch.git
```

关键文件：`src-tauri\src\commands\misc.rs`

Windows 启动逻辑核心（伪代码）：

```rust
let bat_content = format!(
    "@echo off\nclaude --settings \"{}\"",
    config_path
);
// 写到临时 .bat，用 CC Switch 自己的进程环境启动它
```

也就是说，CC Switch 生成的临时 `.bat` 就是裸的：

```cmd
claude --settings "<临时配置.json>"
```

没有任何 `--dangerously-skip-permissions`，而且这个 `.bat` 运行在 **CC Switch 进程继承的旧 PATH** 里。

---

### 4. 关键反转：日志证明 wrapper 没被启动

给 `.cc-switch\bin\claude.cmd` 加了日志写入，然后从 CC Switch 重新打开 Claude。

检查日志：

```cmd
type "%USERPROFILE%\.cc-switch\logs\claude-wrapper.log"
```

**没有** `wrapper-invoked`。只有之前手动测试时留下的记录。

同时最新临时 settings 也没有被 patch，仍然只有：

```json
{ "env": {} }
```

结论：**进 Claude 后看到的 `where claude` 是 Claude 运行后的工具环境 PATH，不是 CC Switch 启动 Claude 那一刻的 PATH。**  
CC Switch 本身继承的是旧 PATH，它更早命中了 `%APPDATA%\npm\claude.cmd`，而不是 `.cc-switch\bin\claude.cmd`。

---

### 5. `--settings` 覆盖了 `~/.claude/settings.json` 的关键字段

用户的 `~/.claude/settings.json` 里有：

```json
{
  "skipDangerousModePermissionPrompt": true,
  "allowDangerouslySkipPermissions": true
}
```

但 CC Switch 通过 `--settings <临时json>` 启动时，这个临时 settings 成为当次会话的 settings 来源，而它只有：

```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "***",
    "ANTHROPIC_BASE_URL": "https://example.com",
    "PATH": "..."
  }
}
```

没有任何权限相关字段。这解释了为什么单改 `~/.claude/settings.json` 不管用。

---

## 修复方案

### 一键安装脚本（推荐）

```cmd
git clone https://github.com/xzyj50609/cc-switch-bypass-permissions.git
cd cc-switch-bypass-permissions\scripts
install.bat
```

脚本做的事：
1. 备份 `%APPDATA%\npm\claude.cmd` → `claude-real.cmd`
2. 把 `claude-wrapper.cmd` 安装为新的 `claude.cmd`
3. 把 `patch_ccswitch_claude_settings.py` 复制到 `%USERPROFILE%\.cc-switch\bin\`

---

### 手动修复步骤

**第 1 步：备份原始 npm shim**

```cmd
copy /Y "%APPDATA%\npm\claude.cmd" "%APPDATA%\npm\claude-real.cmd"
```

原始文件内容大致是：

```cmd
@ECHO off
GOTO start
:find_dp0
SET dp0=%~dp0
EXIT /b
:start
SETLOCAL
CALL :find_dp0
"%dp0%\node_modules\@anthropic-ai\claude-code\bin\claude.exe" %*
```

---

**第 2 步：下载并放置 patcher**

把 `scripts\patch_ccswitch_claude_settings.py` 复制到：

```text
%USERPROFILE%\.cc-switch\bin\patch_ccswitch_claude_settings.py
```

创建目录（如果不存在）：

```cmd
mkdir "%USERPROFILE%\.cc-switch\bin"
mkdir "%USERPROFILE%\.cc-switch\logs"
```

---

**第 3 步：用 wrapper 覆盖 npm shim**

把 `scripts\claude-wrapper.cmd` 复制到：

```text
%APPDATA%\npm\claude.cmd
```

注意：wrapper 调用的是 `%~dp0claude-real.cmd`，即同目录下的备份，**不会递归**。

> ⚠️ 错误做法：`wrapper -> %APPDATA%\npm\claude.cmd`（会递归死循环）  
> ✅ 正确做法：`wrapper -> %APPDATA%\npm\claude-real.cmd -> node_modules\...\claude.exe`

---

**wrapper 的行为**

当参数包含 `--settings <path>` 时（即 CC Switch 启动场景）：

1. 运行 patcher，给临时 settings 注入：
   ```json
   {
     "skipDangerousModePermissionPrompt": true,
     "permissions": { "defaultMode": "bypassPermissions" }
   }
   ```
2. 写日志到 `%USERPROFILE%\.cc-switch\logs\claude-wrapper.log`
3. 调用 `claude-real.cmd --dangerously-skip-permissions <原参数>`

普通命令（如 `claude --version`）直接透传，不加危险模式参数。

---

## 如何验证修复成功

**1. 验证不递归**

```cmd
claude --version
```

应该正常输出版本号，不报错、不卡死。

**2. 从 CC Switch 重新打开 Claude 终端后，看 wrapper 日志**

```cmd
type "%USERPROFILE%\.cc-switch\logs\claude-wrapper.log"
```

应该能看到：

```text
2026-06-13T... patched-settings path=%TEMP%\claude_<provider-id>_<pid>.json ...
2026-06-13T... wrapper-invoked
```

**3. 看 Claude 会话权限模式**

最新会话文件（在 `%USERPROFILE%\.claude\projects\...` 下）搜索 `permissionMode`，应该是：

```json
{"type":"permission-mode","permissionMode":"bypassPermissions"}
```

---

## 如何回滚

```cmd
cd cc-switch-bypass-permissions\scripts
uninstall.bat
```

或手动：

```cmd
copy /Y "%APPDATA%\npm\claude-real.cmd" "%APPDATA%\npm\claude.cmd"
```

---

## 如何判断是否复发

CC Switch 或 Claude Code 更新后，如果问题复发，按以下顺序检查：

**1. wrapper 日志有没有最新的 `wrapper-invoked`**

```cmd
type "%USERPROFILE%\.cc-switch\logs\claude-wrapper.log"
```

有 → wrapper 正常运行，问题在别处。  
没有 → wrapper 没被启动，可能 npm shim 被更新覆盖了。

**2. npm shim 是否被更新覆盖**

```cmd
type "%APPDATA%\npm\claude.cmd"
```

如果内容变回了原始 npm shim（没有 `claude-real.cmd` 引用），说明 Claude Code 更新时覆盖了 wrapper，重新执行 `install.bat` 即可。

**3. 最新临时 settings 是否被 patch**

```text
%TEMP%\claude_*.json
```

打开最新的，看是否含 `skipDangerousModePermissionPrompt` 和 `permissions.defaultMode`。

---

## 这次排查的几个教训

### `where claude` 要分层看

在 Claude 会话里跑 `where claude`，看到的是 **Claude 运行后的工具环境 PATH**，不是 CC Switch 启动 Claude 进程时的 PATH。

这是整个排查里最容易被误导的地方。**正确的证据是 wrapper 日志，不是 `where claude`。**

### `--settings` 不是普通 env 注入

CC Switch 不是：

```cmd
set ANTHROPIC_BASE_URL=...
claude ...
```

而是：

```cmd
claude --settings "<临时配置.json>"
```

`~/.claude/settings.json` 里的字段不一定参与本次启动。要让 bypass 生效，必须 patch 这个临时 settings。

### wrapper 要接管 npm shim，而不是加在 PATH 前面

把 wrapper 放到 `env.PATH` 最前面只能影响 Claude 启动后的环境，不影响 CC Switch 自己继承的旧 PATH 里用什么来启动 Claude。必须接管 npm shim 本身。

### 用日志证明 wrapper 真的执行了

反复看 `where claude` 不如看一次 wrapper 日志可靠。日志里的 `wrapper-invoked` 是唯一确凿的证据。

---

## 打赏

如果这篇排障记录帮你省下了几个小时，欢迎请我喝杯咖啡。

<table>
<tr>
<td align="center"><b>微信支付</b></td>
<td align="center"><b>支付宝</b></td>
</tr>
<tr>
<td><img src="../profile/assets/wechat-pay.jpg" width="200"></td>
<td><img src="../profile/assets/alipay.jpg" width="200"></td>
</tr>
</table>

---

## 参考链接

- [CC Switch 用户手册](https://github.com/farion1231/cc-switch/blob/main/docs/user-manual/zh/README.md)
- [CC Switch 切换供应商](https://github.com/farion1231/cc-switch/blob/main/docs/user-manual/zh/2-providers/2.2-switch.md)
- [Claude Code CLI 参考](https://code.claude.com/docs/zh-CN/cli-reference)
- [Claude Code 权限模式](https://code.claude.com/docs/en/permission-modes)
