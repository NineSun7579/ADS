# 验证结果（2026-11-04）

- 最终源码在 epsilon 的 `ads-cross-bench` Docker 完整 ARM 交叉编译、链接通过。
- 构建目录 `/home/epsilon/ads-cross-bench/ads-production-live-only-20261104/build-arm`。
- 产物 `ads-production-live`：ELF 64-bit ARM aarch64，真实 sysroot Qt/OpenCV/RKNN/RGA 链接。
- ELF SHA256：`ede8c7bccdd03663503f6cf2311f17c7a2c3108711c53619829189bbe5440ac5`。
- `check-production.py` 通过：fair 调度只选 ready、无 blackImage/假序号生成、
  两级 synthetic 提交拒绝、无 blackInput；ARM 预处理后的 main 中不存在
  ReplayInput 构造、归档文件读取、local_video 调用、ffmpeg 解码启动或 AvmSim 文件采集。
- 强行定义 `ADS_ENABLE_TEST_INPUTS=1` 的编译探针失败（符合生产契约）。
- `git diff --check -- ads/production` 通过。原样上游空白及 delta context 按 attributes 免检。
- 构建有上游 unused/sign-compare 警告，无编译错误。初次 buildbox 缺 qmake，
  换用已有 ads-cross-bench 工具链；没有修改工具环境。
- 未执行生成的 ADS，不部署、不切服务、不运行视频、不提交/推送。
  未做板端摄像头、模型精度或按钮交互运行验收。

源码可用 `git diff -- ads/production` 审查；仅本目录执行 intent-to-add，
没有暂存实际文件内容。相对真实下载基线的小范围差异见 `SOURCE_DELTA.patch`。
