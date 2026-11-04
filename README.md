# 星途驭境——FPGA + ARM 异构辅助驾驶系统

本项目基于紫光同创 FPGA 与 RK3568 ARM 主控，面向车载多路视频采集、环境感知与辅助驾驶。系统通过双 FPGA 协同完成视频采集、预处理和传输，由 ARM 侧承担模型推理、感知显示及驾驶辅助状态管理。

仓库包含 `100H`、`50K` 两套配套 FPGA 工程，以及 `ads/production/` 下的 ADS 正式版 ARM 源码。FPGA 工程和 ARM 程序分别构建；上传源码不代表已完成整机联调或板端验收。

## 系统组成

整体硬件方案接入六路 OV5640 摄像头和一路物理 HDMI，双 FPGA 通过光纤互联，并通过 PCIe 与 RK3568 交换数据。具体接口、器件配置和约束以各 FPGA 工程为准；ARM 正式版包含四路推理调度，不能将硬件输入总数等同于同时推理路数。

| 组成 | 主要职责 | 源码与说明 |
| --- | --- | --- |
| 100H FPGA | 视频与车道检测相关 I/O、时序及数据链路 | [100H/](100H/)、[工程说明](100H/README.md) |
| 50K FPGA | 配套 HDMI 发送链路 | [50K/](50K/)、[工程说明](50K/README.md) |
| RK3568 ARM | 真实输入推理、车道识别、测距、感知界面及驾驶辅助状态机 | [ads/production/](ads/production/)、[正式版说明](ads/production/README.md) |

项目围绕目标识别、车道感知、测距和车辆行动预测组织辅助驾驶功能。识别精度、推理帧率及道路表现需要在实际硬件和输入条件下测量，本仓库不以编译结果代替这些指标。

## 目录导航

```text
.
├── 100H/                       # 100H FPGA：RTL、IP、约束与构建脚本
├── 50K/                        # 配套 FPGA：HDMI 发送工程
├── ads/production/             # ADS 正式版源码与构建、检查脚本
│   ├── host/viewer/ads-production.pro  # ARM 正式构建入口
│   ├── build-arm.py            # ARM 交叉编译
│   ├── check-production.py     # 源码及 ARM 预处理契约检查
│   ├── start-production.sh     # 目标设备启动脚本
│   ├── SOURCE_PROVENANCE.json  # 上游来源及文件哈希
│   ├── SOURCE_DELTA.patch      # 相对冻结上游的源码差异
│   └── VALIDATION.md           # 历史构建与验证记录
├── PROJECTS.md                 # FPGA 交付、环境及验收边界
├── ADS_PRODUCTION_BRANCH.md    # ARM 正式版整理背景与范围
├── ADS_SOURCE_BASELINE.json    # ARM 源码基线记录
├── PRODUCTION_REVIEW.md        # 正式版审查要求
└── SOURCE_FILES.json           # 交付文件大小及 SHA256 清单
```

## ADS 正式版运行边界

- 仅接受真实摄像头与物理 HDMI，不接受本地视频、归档回放、模拟输入或播放器远程控制。
- 四路推理仅调度当前有效且新鲜的真实帧；没有可用输入时跳过推理，不生成黑帧或虚构检测结果补位。真实摄像头拍到黑色画面仍可构成有效输入。
- 保留真实检测、车道识别、测距、感知显示和状态机，以及行驶、停止、假定车道和变道等用户请求。
- 用户请求不直接等同于执行许可；证据不足时保持未知或等待。
- 正式入口固定启用 `ADS_PRODUCTION_LIVE_ONLY=1`，显式启用 `ADS_ENABLE_TEST_INPUTS=1` 会触发编译失败。

完整约束见 [正式版说明](ads/production/README.md) 和 [源码审查范围](PRODUCTION_REVIEW.md)。

## 获取与构建

```sh
git clone https://github.com/NineSun7579/ADS.git
cd ADS
```

### FPGA 工程

需要 Windows、Python、相应版本的 Pango PDS 和有效器件许可证。以下命令在仓库根目录的 PowerShell 中执行，PDS 路径按本机安装位置调整：

```powershell
# 100H：在工程目录运行全流程构建
Push-Location .\100H
python .\build.py --pds C:/pango/PDS_2022.2-SP6.4 --stage full
Pop-Location

# 50K：在工程目录运行全流程构建
Push-Location .\50K
python .\tools\build.py --pds C:/pango/PDS_2022.2-SP6.4/bin/pds_shell.exe --out C:/work/50k_full
Pop-Location
```

器件、IP、约束、时序要求和构建阶段详见 [FPGA 工程交付与构建说明](PROJECTS.md)。

### ARM 正式版

构建目标为 `ads-production-live`，入口为 `ads/production/host/viewer/ads-production.pro`。交叉编译依赖 AArch64 工具链、qmake，以及包含 Qt、OpenCV、RKNN、RGA 的目标 sysroot。

现有脚本依赖已配置的 Docker 交叉编译环境和 `/work/sysroot`。将仓库挂载为容器内 `/work/ADS` 后，在该环境中执行：

```sh
python3 /work/ADS/ads/production/build-arm.py
python3 /work/ADS/ads/production/check-production.py
```

产物位于 `ads/production/build-arm/ads-production-live`。仓库未附带工具链、sysroot、部署模型或可直接运行的整机镜像；目标设备运行依赖和安装路径见 [正式版说明](ads/production/README.md)。

## 验证状态

以下为随源码交付的历史记录，上传及文档更新未重新执行硬件构建或运行验收：

| 范围 | 已记录结果 | 
| --- | --- |
| FPGA | 两个工程完成搬迁副本的全新 PDS compile 和本地依赖校验 | 
| ARM | 交叉编译、链接通过，生成 AArch64 ELF；生产输入契约检查通过 | 

ARM 详细记录见 [VALIDATION.md](ads/production/VALIDATION.md)，FPGA 验收边界见 [PROJECTS.md](PROJECTS.md)。来源、差异和文件哈希可通过交付清单追溯；这些记录中的原分支名、绝对路径和操作授权描述属于交付时的历史上下文。

构建缓存、临时归档和工具许可证不随源码交付。厂商 IP、SDK 和第三方组件的使用与分发须遵守各自许可。
