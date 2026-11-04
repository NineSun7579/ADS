# 100H 最新源码工程（ctrlchain8 / seed62）

这是从 **RTL + 已生成 IP HDL + 原约束**重新编译的交付，不依赖旧工程的 mapped/routed 数据库，不需要在另一台电脑打开 PDS GUI 或重新配置 IP。

## 环境与使用

- Windows，Python **3.10 或更新**（仅标准库），PowerShell 5.1 或更新。
- 必须合法安装 **Pango PDS / Fabric Compiler 2022.2-SP6.4 build 146967**，安装 Logos2 / PG2L100H 器件支持并配置有效许可证。脚本核对版本，不下载工具、不携带许可证、不绕过加密。
- FPGA：**Logos2 PG2L100H / -6 / FBG484**，顶层 `top`。其他 PDS 版本未经验证，脚本拒绝自动使用。
- 自动搜索 `PDS_HOME`、`PDS_ROOT`、PATH、`C:/pango/PDS*/bin` 和 Program Files/Pango；也可显式指定安装目录或 `pds_shell.exe`。

```powershell
python build.py --verify-only
python tools/test_delivery.py
python build.py --stage compile
python build.py --pds C:/pango/PDS_2022.2-SP6.4 --stage full
# 或： .\build.ps1 -Pds C:/pango/PDS_2022.2-SP6.4 -Stage full
# 指定新的输出目录： --work D:/fpga_build/100H_run1
# 等待后台构建： .\wait.ps1 -WorkDir <输出目录>
# 后台启动并输出 PID / 日志 / 等待命令： .\launch.ps1 -Stage full
```

默认输出到 `build/<时间戳>/`。指定目录必须不存在，防止复用旧网表；中断后使用新的目录重新开始。`compile` 只编译；`map` 从头编译、综合和映射；`full` 从头执行 compile → synthesize → dev_map → PnR → full STA → 审核 → bitgen。没有从旧数据库继续构建的选项。PDS 返回非零、日志错误、完整时序审核失败、输入哈希改变均停止，不生成新 bitstream。

PnR 固定 seed **62**，保持原全部选项，仅增加 `-max_ctrl_chain_length 8`，详见 `build.py` 的 `PNR_OPTIONS`。STA 固定 `min_max / nworst 1 / max_path 15000 / input_pins / report_exception`。流式审核包含慢/快角 Setup、Hold、Recovery、Removal、Minimum Pulse Width 共 **10 类**，要求 All Constraints Met、端点/TNS 合格并检查详细 Slack。报告上限和原异步例外仍然存在，审核不等于完整接口签核。

完整构建至少预留 **11 GiB** 空间（8 GiB 保留 + 3 GiB 报告预算；实际增长可能更多），STA 报告约 2.47 GB。脚本逐阶段检查剩余空间，不删除任何已有文件。不建议同时运行其他大规模 PnR。`result.json`、各阶段 stdout、PID、tool_version、timing_review 和最终 bitstream 全部在输出目录。

## 内容、来源与跨机边界

- `source/`：完整业务 RTL、约束，以及 divider 等已生成 IP；`ipcore/`：DDR3、PCIe、HSST、FIFO、PLL 等已生成 HDL/加密 HDL、IDF、参数及初始化常量。不是只交 wrapper，也不需要重新生成 IP。
- `project/top.pds`：原未运行的 source-only 工程，源/IP/约束均使用相对路径。脚本在新工作目录生成临时工程，仅把这些路径定位到当前副本，保留原设置。
- `MANIFEST.json`：输入完整哈希；`reference/import_provenance.json`：原 prepared_plan/source_manifest 对照、原文件逐项哈希及排除项。`reference/` 的历史报告/Tcl仅用于溯源，绝不作为新构建输入。
- `tools/dependency_audit.json`：工程条目、Verilog include、readmem 和绝对路径审核。原 PCIe 文件中历史 `INIT_FILE=C:/...` 或 `E:/...` 字符串仍保留以维持源码哈希，但实际 `.c_INIT_FILE("NONE")`，初值由已附 `*_init_param.v` 常量提供；不是跨机读取依赖。示例子工程的旧 E: 路径不属于顶层工程的活动输入。加密 HDL 内部由 PDS 解密处理，无法静态穷尽审计；搬迁后 vendor compile 是必要验证。
- 原缓存、备份、仿真 C 模型二进制和非引用日志已排除；项目引用的少量 generator 文本保留以避免悬空条目。未带 mapped/routed ADF、编译缓存、巨型报告、网表或 bitstream；`.gitignore` 排除所有新输出。不创建 `.git`，不 commit，不上传。

参考历史产物 `top.sbit` SHA256：
`3ccdaa213355d9cf1955701993d7e1a3b8826f48fde04d545855ab3712abf50f`。
它来自 `v10_lane_io_ctrlchain8_20261103`，映射输入来自 `v10_lane_io_scratch_build_20261103`。本工程 source/IP 按 prepared_plan 哈希核对导入。**新全量构建尚不能保证通过或逐字节复现该参考 bitstream**；布局、工具环境和输出元数据都可能影响结果，seed 不代表时序必过。

## 重要限制与授权

历史参考有 **62 个输入、71 个输出时序约束警告**，并存在许可证期限警告；不等于 I/O 已完整约束、CDC/协议验证或板级通过。参考 setup 最小裕量 0.043 ns、pulse 0.011 ns，不能据此承诺鲁棒性。当前交付验证状态见 `validation.json`，不要把历史 PASS 当作本次新构建 PASS。没有烧录、OTA、板卡连接或 GUI 操作。

Pango 生成/加密 IP 和仿真模型保留原版权，使用与再分发受供应商授权约束；用户必须自行确认能否上传这些文件，**不将供应商 IP 声称为开源**。AXI 等第三方 RTL 中现有 MIT 等许可声明保留。未给原创代码另设许可证；拥有源码不自动授予第三方再分发许可。若平台仅接受 corecode，也必须附全部活动 generated IP/初始化常量/约束，否则不能保证从零编译。
