# ADS 正式版：仅真实输入

本目录是独立可审查源码，不替换仓库历史 runs。唯一生产构建入口是
`host/viewer/ads-production.pro`，目标 `ads-production-live`，始终定义
`ADS_PRODUCTION_LIVE_ONLY=1`。主源码未带该宏拒绝编译；
`ADS_ENABLE_TEST_INPUTS=1` 直接编译失败，运行态 ENV 不能开启模拟输入。
本轮未部署、未切服务、未运行 ADS/视频、未提交或推送。

## 来源与审查

实际冻结来源：`epsilon:/home/epsilon/ads-cross-bench/ads-four-fair-20261104/host`，
2026-11-04。不是 git HEAD 旧宿主，也不是 HTTP overlay 分支。
`SOURCE_PROVENANCE.json` 保存来源、两个源码归档 SHA256 及每个上游文件 SHA256。
下载的首个归档 SHA256 为
`66225f4c2c1eb1b8008258fecc0aa5a59d7f2b6d8dc70bf36c13f33d9a5093ae`。
第二个归档补全原样 selftest 编译依赖与真实 Rockchip API 声明；没有 x86 RKNN stub。
`host/` 是完整源码快照（约 33 MiB，含现有 UI 和必要 third_party），
`SOURCE_DELTA.patch` 是相对该真实上游的源码差异。
归档、临时传输包和构建输出不纳入 git；`snapshot-review.py` 可从本地冻结归档重新生成审查记录。

## 生产边界

- 不引入 HTTP remote 分支，无 HTTP 监听或 commands 服务。
- ReplayInput 的 include/构造、UDP 接收和 mediaPoll 整段编译剔除；
  perceptionBirdFrame 不接受归档场景覆盖；Replay 来源选择拒绝，F8 无操作，沙箱控制返回 false。
- 启动在所有 selftest/Qt/设备初始化之前校验参数，未知 `--` 参数、
  selftest、preview、video/local-video、replay、remote/http、simulate/demo、suite/scenario、t1..t5 返回 2。
  CLI 使用源码中明确生产选项集合；新增生产参数须显式审查加入。
- 启动及 Controller 不读取本地视频配置；本地视频保存/exit42、视频解码、
  AvmSim 视频采集、进程 reexec 均编译剔除；setVideoSource 不接受来源。
  UI 移除本地视频选择/暂停/循环命中与绘制，物理 HDMI 页面保留真实融合按钮。
- Lamp 演示操作不再修改灯色；三个回放预测开关是编译期 false，
  不从 t1..t5 sidecar 推导许可。用户车道假定、方向请求、驾驶按钮仍保留，不能等同规则许可。
- 四路保留 least-served/旋转公平调度，仅在 ready 中选择；无 ready 直接返回。
  ready 仍要求当前 generation/acquisition、未提交帧号和不超过 500ms 的真实采集时间。
  不创建 blackImage/假帧号；Controller 和 InferenceThread 同时拒绝 syntheticBlack；
  推理预处理不调用 blackInput。真实相机拍到黑色画面仍是有效真实帧，模型 letterbox 不受影响。

共享历史实现、selftest 编译单元和部分回放类型名称保留，便于最小差异构建；
这些符号不是正式入口。禁止以环境变量默认关闭替代以上边界。
模型 `.names` / deployment sidecar 是模型元数据校验，继续保留，与归档假证据无关。
真实 lane 渲染、状态机新鲜度/未知拒绝许可、相机/物理 HDMI、用户按钮及测距沿用实际基线，
未重设计业务算法。现有实时 HDMI 鱼眼辅助进程仅消费带 epoch 的真实物理帧，仍需目标设备已有运行依赖。

## 构建与验证

只在 epsilon 的 `ads-cross-bench` Docker（ARM 交叉工具链和现有 sysroot）中：

```sh
docker exec ads-cross-bench python3 /work/ads-production-live-only-20261104/build-arm.py
docker exec ads-cross-bench python3 /work/ads-production-live-only-20261104/check-production.py
```

脚本构建独立目录，不在 Windows 或板端编译。首次尝试 buildbox 缺 qmake，
已改用具备工具链的 ads-cross-bench；没有修改外部工具环境。
`check-production.py` 检查真实帧调度与三重 synthetic 入口，检查 ARM 预处理产物
无 UDP/media/archive/local-video/AvmSim 采集，检查强开测试宏失败，以及 ELF 为 AArch64。
启动示例见 `start-production.sh`，本轮没有执行它；不会打包 backend/player/videos 或测试媒体。
设备运行、相机画面及交互验收尚未进行，交由用户实际使用检查。

快照中的 Rockchip API 头文件尾空格和 mono_motion.h 末尾空行原样保留；
`.gitattributes` 仅对这些上游文件及生成的 unified diff 关闭空白诊断，避免改写来源。
