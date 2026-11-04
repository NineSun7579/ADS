# 50K v10 seed1：独立可重建源码工程

本目录来自 `C:\nh_build\s50v10c`，不是 `s50v10d`。与主工程选定的最新 100H ctrlchain8 配对；不包含或修改 100H。器件参数直接取自原工程：**Logos / PGL50H / -6 / FBG484**，顶层 `hdmi_ddr_ov5640_top`。原工具 **PDS 2022.2-SP6.4 build 146967**。

## 不需要重新配置 IP

已保留原始 `source/rtl`、5 个已配置 `.idf`、生成的 Verilog/加密 `.vp`、DDR3/HSST 子模块与约束、RAM 初始化参数文件与 `.dat`。无需 GUI、无需 IP Generator，不以空壳接口替代 IP。原始源码未改写。原工程中没有需要额外搬运的独立 core netlist；IP 综合源表全部随包提供。PDS 器件库、primitive 库及有效工具/IP 授权仍由安装环境提供，**不随源码分发工具或授权**。厂商源码/加密 IP 原版权与使用限制继续有效，上传公共仓库前应自行确认分发授权。

## 命令行

要求 Windows、Python 3.10+（仅标准库）、已安装并授权的上述 PDS。建议工作路径使用短英文路径，预留足够磁盘空间（完整 STA 报告可能超过 2 GB）。不连接板卡、不烧录、不联网。

```powershell
# 校验源码哈希、工程及 IP 依赖，不运行 PDS
python .\tools\build.py --stage audit
# 只进行全新 compile，用于迁移验证
.\build.ps1 --pds 'C:\pango\PDS_2022.2-SP6.4' --stage compile --out 'C:\work\50k_compile'
# 全流程；输出目录必须不存在，避免误用旧数据库
.\build.ps1 --pds 'C:\pango\PDS_2022.2-SP6.4\bin\pds_shell.exe' --out 'C:\work\50k_full'
```

也可使用 `PDS_SHELL`（exe）、`PDS_HOME`（安装根目录）、PATH；脚本会搜索常见 `C:\pango`、`D:\pango` 安装目录。`--pds` 优先。所有脚本和工程输入路径相对本目录；`--out` 下复制源码并创建相对输入 Tcl，项目可整体换盘迁移。`nh50v10.pds` 保留原工程输入及参数，仅清除旧产物引用并重置任务状态；命令行脚本不依赖 GUI 的任务状态。

默认全流程：compile → synthesize（`-ads -selected_syn_tool_opt 2`）→ dev_map → PnR（`-gplace_seed 1 -optimize_multi_corner_timing -fix_hold_violation_in_route TRUE -fix_hold_violation_threshold 0`）→ 完整 STA（`-delay_type min_max -nworst 1 -max_path 15000 -input_pins TRUE -report_exception TRUE`）→ 流式严格审查 → bitgen。`--stage map` 停在 dev_map。审查要求 Setup/Hold/Recovery/Removal/Minimum Pulse Width × Slow/Fast 共 10 节非空，任何负 slack、非零 total negative/failing endpoint、详细 `Slack (VIOLATED)`、缺节、重复节或缺少成功摘要均禁止 bitgen；脉宽单时钟列也检查。STA 和 bitgen 使用同一路由数据库并核对 SHA256。日志、子进程 PID 和完成状态见输出目录 `status.json`、各阶段 `.log`。

## 可追溯证据及边界

`provenance/` 只收录小型原始证据，旧绝对路径仅为历史来源，**不用于构建**。`manifest.json` 记录交付源码 SHA256 与已验证产物的参考哈希：原 seed1 SBIT、烧录 SFC、after.sfc、current_readback.sfc 均为 `a4905f5d94a5b29d9da70365b8d72602b046dbd16f44b42bdfdcc8de1da37f70`（2101696 字节）。原 `frozen.json` 的全部 304 输入在打包前逐个验证一致。未携带旧 compile/synthesis/map/route 数据库、巨型报告或 bitstream，不能把历史成功当成本次重建成功。

本次已在迁移后的独立 `validation_compile/` 工作目录完成全新 compile（2026-11-03，PDS PID 107424，1m9s，峰值 302 MB）；原有 dangling/unused logic 警告未改动。详见 `provenance/relocated_validation.json`。本地 `validation_compile/` 仅供查日志，已忽略，不应上传。

**尚未完成本目录的全新综合、布局布线、十节 STA 和 bitgen，不能保证其它机器上的时序或 bitstream 与历史文件字节一致。** 请以新输出目录的 STA 审查与状态为准。加密 HDL 内部无法静态阅读；其依赖由 `.idf` 源表闭包审计和实际 compile 联合验证。审查器的 8 项对抗测试已通过，并对原 2.19 GB 完整 STA 报告流式复核：十节齐全且通过。
