# X-JSON

X-JSON 是一个基于 **SwiftUI + AppKit** 的 macOS 原生 JSON 工具，面向开发者，主打本地解析、结构化编辑、低噪音界面与高效率键盘交互。

[![Download DMG](https://img.shields.io/badge/Download-macOS%20DMG-black?logo=apple)](https://github.com/xx239/X-JSON/releases/tag/pre)

## 下载

- macOS (DMG): [X-JSON-macOS.dmg](https://github.com/xx239/X-JSON/releases/tag/pre)

## 为什么是 X-JSON

- 对剪贴板 JSON 自动识别，减少重复粘贴操作。
- 支持字符串中的嵌套 JSON 递归展开与回写。
- 支持多标签并行处理 JSON，不覆盖当前工作内容。
- 同时提供树视图和文本视图，适配不同编辑习惯。

## 当前功能

### 多标签页

- 新建、关闭、切换、重命名标签页。
- 剪贴板自动解析生成的标签页自动命名为 `clipboard-1`、`clipboard-2`...
- 支持“新建标签”或“覆盖当前标签”两种剪贴板导入策略（可配置）。

### JSON 解析与格式处理

- 支持 `object / array` 根结构。
- 支持格式化与压缩（minify）。
- 错误提示包含原因、行列和上下文片段。

### 树视图

- 默认展开根与首层，支持整树展开/收起。
- 支持双击内联编辑 `key` / `value`（点击其他区域自动提交）。
- 支持新增同级、新增子级、删除节点。
- 支持颜色主题区分 `key/string/boolean/number/null`。
- 数组索引显示为 `[0]:`，不加引号。
- 支持搜索命中高亮并定位。

### 文本视图

- 代码编辑器风格文本区。
- 行号展示（对长字符串内语义行做降噪处理）。
- `Cmd+F` 搜索高亮与 `Next` 跳转。
- 支持 “Sync to Tree” 手动同步到树。

### Inspector 面板

- 展示 Path、Key、Type、Value 及编辑动作。

### 剪贴板监听

- 持续监听文本变化，按内容去重。
- 仅处理可解析 JSON，超限文本自动忽略。
- 应用在编辑文本时复制内容不会重复触发新解析。
- 可选后台检测后自动前置窗口。

### 外观与窗口

- 内置多套主题。
- 支持字体、字号自定义。
- 支持背景透明度调整（35%~100%）。
- 支持窗口始终置顶（Always on top）。

## 快捷键

- `Cmd + V`：粘贴并解析（在搜索框/文本编辑框内优先执行普通粘贴）。
- `Cmd + N`：新建标签页。
- `Cmd + W`：关闭当前标签页。
- `Cmd + 1`：切换 Tree 视图。
- `Cmd + 2`：切换 Text 视图。
- `Cmd + F`：显示/隐藏搜索栏。
- `Cmd + G`：搜索下一个结果。
- `Cmd + Shift + F`：格式化 JSON。
- `Cmd + Shift + M`：Minify / Format（根据当前状态切换）。
- `Cmd + Z`：撤销。
- `Cmd + Shift + Z`：重做。

## 设置项

设置窗口分为 `General`、`Window`、`Clipboard`、`Tabs`、`Advanced`：


## 架构模块

- `WindowCoordinator`：窗口激活、置顶、透明度行为。
- `TabSessionManager`：标签页、模式切换、搜索、编辑、撤销重做。
- `ClipboardMonitor`：剪贴板轮询监听、去重、过滤、回调。
- `JsonParseService`：JSON 解析、格式化、压缩、错误定位、容错规范化。
- `EmbeddedJsonDetector`：字符串中嵌套 JSON 识别。
- `JsonTreeBuilder`：将 JSON 数据构建为树节点结构。
- `JsonEditService`：结构化编辑（改 key/value、增删节点、类型转换）。
- `SettingsService`：本地设置持久化（`UserDefaults`）。

## 项目结构

```text
JSONLens/
├── App/
├── Models/
├── Services/
├── State/
├── Views/
│   ├── Components/
│   └── Settings/
└── Resources/
```

## 开发环境

- macOS 13+
- Xcode 15+（推荐）
- Swift 5.10

## 本地运行

### 方式一：Xcode

1. 用 Xcode 打开工程目录（Swift Package）。
2. 选择可执行目标 `X-JSON`。
3. 运行。

### 方式二：命令行

```bash
swift build
swift run X-JSON
```

## 数据与隐私

- 所有 JSON 处理均在本地完成。
- 应用设置持久化在本机 `UserDefaults`（键：`xjson.app.settings`）。
