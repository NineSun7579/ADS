# 设计导出契约 v2（design.json / bindings.json）

本文件是导出端与运行端的唯一依据。当前引擎按 v1 字段渲染，v2 落地后 v1 的“按样例文本猜语义”逻辑全部删除。

## 0. 不做什么

不导出 `.ui`、不生成 C++ 源码、不内嵌资源进二进制。界面永远是「JSON + 外部位图 + 运行时解释」，C++ 只负责通用渲染与业务适配。

## 1. 文件布局

工程根目录 `assets/` 是当前资源唯一来源；根 `manifest.json` 的 `current` 指向它。ZIP 与 exports 目录由 `tools/package-v2.mjs` 生成，不独立维护。更新流程见 `DELIVERY_WORKFLOW.md`；C ABI v1 接口见 `FACADE.md`。

每页必须有稳定 `key`（single/multi/space/four/six）；manifest.pages 同时声明 `key`、Figma `id` 与 `canvas:{w,h}`。不得按页面数组下标识别业务页面。统计节点 `stats.count` 必须带 `bindingIndex` 0..4，对应机动车/行人/自行车/公交车/摩托车；`channel.*` 保持 `channelIndex`。运行时完整键为 `binding:index`。无统计条的页面无需补造节点。

每次导出同时生成 token 版 `design.json`、RGBA 已展开版 `design.resolved.json` 和供评审的 `design.pretty.json`。前两者压缩输出；业务运行时 text 仍为空，颜色展开不把 sampleText 写入 text。`--mode token|resolved` 决定 manifest.entryDesign 和 requires.tokenResolution，不改变 design.json 的语义。

manifest 必须包含 formatVersion、apiVersion、current、designs、entryDesign、pages、bindings（name/type/indexed/indexKind/indexValues）、requires、fonts、files（相对路径/sha256/bytes）。requires 声明所选入口是否需要 token 解析及最低 Qt 5.15。字体以系统 Noto Sans SC 为校准目标，未提供子集；font-map.json 明确替代关系。部署校验入口为 `node tools/verify.mjs <目录> --json`，零 npm 依赖，退出码 0 表示通过。

```
assets/
  design.json          # 压缩 token 引用版
  design.resolved.json # 压缩 RGBA 对象版
  design.pretty.json   # 可读 token 版
  font-map.json        # 系统字体校准及映射
  bindings.json        # 业务数据契约（binding 的类型/单位/格式/空值/时效）
  tokens.json          # 颜色与状态 token
  fonts/               # 随包字体（可选，子集化）
  images/<sha1>        # 单倍位图或 SVG
```

运行端只从磁盘目录读取（`ADS_DESIGN_DIR`，默认 `assets/`）。qrc 回退在 v2 删除：板端交付不允许内嵌，因为 38 张 PNG 解码后约 88MB，直接 OOM。

## 2. 页面与几何

```jsonc
{
  "formatVersion": "2.0",
  "pageSize": { "w": 1600, "h": 1000 },   // 设计坐标系
  "scalePolicy": "fit",                    // fit | fill | stretch
  "pages": [{
    "id": "page:six",
    "name": "感知监控 · 六路视图",
    "role": "page",
    "children": [ /* 节点树 */ ]
  }]
}
```

`scalePolicy` 由页面声明，运行端不再各页各写一套：

- `fit`：等比缩放到视口内，剩余区域留底色（默认）。
- `fill`：等比缩放到铺满视口，超出裁掉。
- `stretch`：非等比拉伸铺满（仅当设计确实按目标比例出图时使用）。

节点通用字段（与 v1 兼容，新增用 `role`）：

```jsonc
{
  "id": "37:1375",
  "name": "按键标签",
  "type": "TEXT | RECTANGLE | ELLIPSE | VECTOR | GROUP | FRAME",
  "role": "button-label",
  "size": { "x": 84, "y": 40 },
  "transform": { "m00":1,"m01":0,"m02":512,"m10":0,"m11":1,"m12":680 },
  "visible": true,
  "opacity": 1,
  "children": []
}
```

## 3. 文本节点：静态与业务严格分离

```jsonc
{
  "type": "TEXT",
  "role": "stat-value",
  "text": "",                       // 业务节点必须为空字符串
  "sampleText": "融合目标 17 个",   // 仅预览/设计对照使用
  "binding": "stats.fusedCount"
}
```

规则：

1. 有 `binding` 的节点，`text` 必须为 `""`，占位写 `sampleText`。
2. 没有 `binding` 的节点是静态文案，只需 `text`，不得写 `sampleText`。
3. 运行模式（`runtime`）**只读运行值**；缺数据渲染 `bindings.json` 里的 `emptyText`，绝不回退 `sampleText`。
4. 预览模式（`preview`）可以显示 `sampleText`，用于设计比对，命令行开关切换。
5. 这条是验收硬指标：断开数据后，运行模式屏幕上不得出现任何样例数字。

排版字段（全部保留并补齐）：

```jsonc
"fontSize": 20,          // px，设计坐标系
"fontFamily": "Noto Sans SC",
"fontStyle": "Regular | Medium | Bold",
"align": "LEFT | CENTER | RIGHT",
"baseline": 15.2,        // 从文本框顶边到首行基线，px
"lineHeight": 26,        // 行盒高度，px；不写时按 fontSize*1.3
"letterSpacing": 0,      // px，默认 0
"lines": 1               // 期望行数，用于换行后的裁切校验
```

`baseline` 从文本框顶边量起，避免跨字体 ascent/descent 差异把头字裁掉。随包字体为 `fonts/` 下的 OFL 字体子集（仅页面用到的字符），运行端优先用它，缺失再回退系统字体。

## 4. 业务绑定契约（bindings.json）

`design.json` 只引用 binding 名，类型和格式化全部集中声明：

```jsonc
{
  "version": 2,
  "bindings": {
    "stats.fusedCount": {
      "type": "integer",
      "format": "融合目标 {v} 个",
      "emptyText": "融合目标 -- 个",
      "range": { "min": 0, "max": 999 },
      "freshnessMs": 3000
    },
    "channel.distance": {
      "type": "number",
      "unit": "m",
      "precision": 1,
      "format": "{v} 米",
      "emptyText": "-- 米",
      "range": { "min": 0, "max": 200 },
      "freshnessMs": 1500
    },
    "channel.fps": {
      "type": "number",
      "precision": 0,
      "format": "{v} 帧/秒",
      "emptyText": "-- 帧/秒"
    },
    "channel.connected": {
      "type": "boolean",
      "map": { "true": "已同步", "false": "离线" },
      "emptyText": "离线"
    },
    "vehicle.action": {
      "type": "enum",
      "values": ["待命", "行驶中", "已停车", "变道中"],
      "emptyText": "待命"
    }
  }
}
```

规则：`binding` 出现未在 `bindings.json` 声明的名字，导出直接失败。单位、精度、格式、空值文案、取值范围、过期时间都在这层，运行端不再硬编码“米”“帧/秒”。

## 5. 视频槽

```jsonc
{
  "binding": "frame",
  "role": "video-slot",
  "slot": {
    "index": 0,                 // 通道号，0..5
    "rect": { "x": 20, "y": 120, "w": 640, "h": 360 }   // 页面坐标，父级变换已合成
  },
  "shape": "rect"
}
```

- `rect` 必须是**最终页面坐标系**下的轴对齐矩形，父级 transform 全部合成完，运行端不再累乘。矩形就是 GL 挖空区域，也是视频贴图落位区域。
- 旋转或斜切的槽必须改用四角：

```jsonc
"shape": "quad",
"quad": [ {"x":0,"y":0}, {"x":640,"y":0}, {"x":640,"y":360}, {"x":0,"y":360} ]
```

四角同样在页面坐标系，顺序为左上、右上、右下、左下。禁止用外接矩形近似旋转槽。

- 运行端负责把页面坐标映射到窗口像素：`viewportRect = f(pageRect, windowSize, dpr, scalePolicy)`。导出端不写死像素坐标。

## 6. 交互

```jsonc
{
  "role": "button",
  "action": "drive",
  "hitRect": { "x": -8, "y": -8, "w": 116, "h": 96 },  // 相对节点自身布局盒的偏移
  "hitPriority": 10
}
```

- 未写 `hitRect` 时命中区等于 `size` 盒。
- 视觉描边超出布局盒的控件（圆形按键、带发光的按钮）必须给 `hitRect`，命中不得小于可见范围。
- 命中区重叠时按 `hitPriority` 大者优先，相同则取渲染层级更高者（后绘制）。
- 绘制与命中共用同一套变换，不允许各算一套。

## 7. 视觉状态与 token

颜色不烧进节点，改为 token 引用：

```jsonc
// tokens.json
{
  "ok_green": "#35d07f",
  "warn_amber": "#f0a93b",
  "danger_red": "#e5484d",
  "idle_gray": "#5b6b78"
}
```

```jsonc
// 节点
"role": "action-card",
"variants": {
  "normal":   { "fill": "@token/idle_gray",    "text": "@token/idle_gray" },
  "active":   { "fill": "@token/ok_green",     "text": "@token/ok_green" },
  "warning":  { "fill": "@token/danger_red",   "text": "@token/danger_red" },
  "disabled": { "fill": "@token/idle_gray", "opacity": 0.4 }
}
```

- `variants` 的每个键声明作用于 `fill`、`stroke`、`text`、`icon` 中的哪些部分。
- 状态由业务模块输入（binding 里给 enum 值），运行端只做「取 variant → 解析 token → 应用」。
- 没有 `variants` 的节点用默认样式，运行端不得自行改色。

### 7.1 按钮、预测输出和测距段

控件根节点声明 `interaction.mode`：`latched`（保持选择）、`momentary`（按压反馈后恢复）或 `output`（只读业务输出）。`stateBinding` 明确对应 `ui.*` 枚举，可写在控件根或 `interaction` 内。静息/活动样式由根节点 `variants` 声明；不得在父子节点上重复叠加静息透明度。

- 行驶/停止属于同一互斥组；左转/直行/右转车道属于另一互斥组。点击改变界面选择并发出 action，业务回传可覆盖显示；界面选择不代表实际车辆状态或行驶许可。
- 变道按钮保持原有活动配色，按住显示按压反馈，释放恢复。每次完整点击触发一次 action。
- 预测输出只接收显式 `ui.prediction*` 状态，默认 `normal`；不携带驾驶 action，不跟随车道按钮选择自动点亮。
- `channel.distanceValue` 为米制距离数字；`channel.distanceSegments` 为从左向右点亮的段数。两项独立输入，不从样例推导，也不在运行端猜测比例关系。每个虚线段使用显式 `channelIndex`、从 0 开始的 `segmentIndex`；索引小于输入段数的段活动，其余静息。
- `ChannelState::distanceSegments` 和 `PerceptionState::visualStates` 是本工程 C++ 适配接口；JSON 消费端可通过同名 binding 自行接入。

## 8. role 枚举

`page | panel | panel-title | tab | tab-active | button | button-label | icon | stat-label | stat-value | badge | video-slot | status-text | action-card | gauge | list-item`

用途：同类型节点统一处理（stat-value 统一格式化与空值、button 统一命中与按压、panel-title 统一字重），不必逐个 id 硬编码。识别不可靠的节点允许人工在导出映射里显式标注，导出时写死。

## 9. 资源

- 外部目录，按需解码，LRU 缓存，设内存上限（默认 128MB，超出按最近最少用淘汰）。
- 优先 SVG；位图只出单倍，不导出 2x/3x。当前 38 张图在 1920×1080 下再大也是缩放浪费。
- 图片节点声明 `imageFill: { "blend": "NORMAL", "fit": "cover|contain" }`，避免运行端各写一套拉伸策略。

## 10. 导出期校验（不过即失败）

1. 业务文本节点必须有 `binding`，且 `text == ""`、`sampleText` 非空。
2. 静态文本节点不得有 `sampleText`，`text` 非空。
3. `binding` 必须在 `bindings.json` 中声明。
4. `frame` 槽必须有 `slot.index` 与 `slot.rect` 或 `shape:"quad"` + `quad`。
5. 引用的 token 必须存在；`variants` 的键必须在允许集合内。
6. `role` 必须在枚举内。
7. 同一页面内 `slot.index` 不得重复。
8. 语义映射是受版本管理的文件（导出端维护，人工首次确认）。节点被删除、改名或映射失效时，导出报错而不是静默跳过。

## 11. 运行端要做的删改

- 删除按样例文本、正则、最近距离推断语义的全部逻辑。
- 删除硬编码的单位与格式化文本，改读 `bindings.json`。
- 增加 `preview | runtime` 模式；runtime 下永不显示 `sampleText`。
- 槽矩形直接取 `slot.rect`，不再从节点 walk 父链累乘。
- 命中改用 `hitRect` + `hitPriority`；绘制与命中共用变换。
- 状态色改由 `variants` + token 驱动。
- 资源按需解码 + 内存上限，删除 qrc 回退。

## 12. 验收

1. 只改 `sampleText` 里的数值，runtime 渲染结果逐像素一致。
2. runtime 断开数据源后，全页文本转储中不出现任何 `sampleText` 内容，只有 `emptyText`。
3. 缺 `binding` 的业务节点、缺 token、缺 slot 索引三种情况，导出脚本退出码非 0 并指出节点 id。
4. 改造前后同一页的槽矩形与当前 `channelRectsInScene()` 输出误差 ≤ 0.5px。
5. 点击落在视觉描边内、布局盒外 2px 处，仍能命中对应 `action`。
6. 字体子集生效：板上与设计稿首行基线偏差 ≤ 1px，无顶部裁切。
