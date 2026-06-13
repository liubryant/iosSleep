# iosSleep 完整开发计划

## 目标

构建一个 iOS 睡眠监测应用，包含三个底部 Tab：

- 声音：使用本地助眠声音资源，支持浏览、播放、收藏、定时。
- 睡眠：基于麦克风音频采集、Mel Spectrogram、Core ML/YAMNet 思路做睡眠声音事件识别与报告。
- 我的：登录入口、协议隐私、权限状态、清除缓存和基础设置。

第一阶段目标是完成可运行的 SwiftUI App 骨架和主要业务闭环。AI 模型部分先提供完整工程接口、模拟分类器和 YAMNet 接入点，等模型文件加入工程后替换为真实推理。

## 技术栈

- SwiftUI：页面、导航、Tab 框架。
- AVFoundation：本地声音播放、麦克风录音、音频会话。
- Core ML：预留 YAMNet 模型加载与推理接口。
- Accelerate：预留 PCM -> Mel Spectrogram 特征提取工具。
- HealthKit：睡眠数据授权、读取、写入接口。
- Swift Charts：睡眠事件、噪音趋势、睡眠统计图表。
- UserDefaults：第一版保存收藏、设置、登录状态。
- FileManager：缓存统计与清理。

## 资源计划

资源来源：

`/Users/liuzheng/Desktop/tide_sounds_dump`

处理规则：

- MP3：复制到 App Bundle 的 `SoundResources`。
- 封面图：导入前压缩为 JPEG，单张控制在 200KB 以内。
- metadata：转换为 App 使用的 `sounds_manifest.json`。
- 资源目录使用 Xcode folder reference 引入，避免 pbxproj 枚举大量文件。

目标目录：

```text
iosSleep/iosSleep/Resources/SoundResources/
├─ sounds_manifest.json
├─ 001_夏威夷海滩/
│  ├─ cover.jpg
│  ├─ sound.mp3
│  └─ metadata.json
└─ ...
```

## App 架构

```text
iosSleepApp
└─ MainTabView
   ├─ SoundHomeView
   ├─ SleepHomeView
   └─ ProfileView

Services
├─ SoundLibrary
├─ AudioPlayerService
├─ SleepMonitorService
├─ AudioFeatureExtractor
├─ SoundClassifier
├─ HealthKitService
└─ CacheService

Models
├─ SoundScene
├─ SleepSession
├─ SleepEvent
├─ SleepEventType
└─ AppSettings
```

## 声音模块

功能：

- 声音场景网格列表。
- 封面、标题、副标题展示。
- 搜索与分类筛选。
- 播放/暂停。
- 收藏。
- 当前播放迷你播放器。
- 睡眠前快捷入口。

实现步骤：

1. 读取 `sounds_manifest.json`。
2. 根据 manifest 定位 Bundle 内封面与 MP3。
3. 使用 `AVAudioPlayer` 播放本地 MP3。
4. 使用 `UserDefaults` 保存收藏。
5. UI 使用 SwiftUI 网格与底部播放器。

## 睡眠模块

功能：

- 一键开始/结束睡眠监测。
- 麦克风权限检查。
- 监测时显示当前状态、环境音量、识别事件。
- 结束后生成睡眠报告。
- 使用 Swift Charts 展示事件时间线与噪音趋势。
- HealthKit 授权入口。

技术实现：

```text
AVAudioEngine Tap
↓
PCM Buffer
↓
AudioFeatureExtractor
↓
Mel Spectrogram
↓
SoundClassifier
↓
SleepEvent
↓
SleepSession Report
```

第一版策略：

- 没有 YAMNet 模型文件时，使用 `MockSoundClassifier` 根据能量、频段和时间生成可演示事件。
- 保留 `YAMNetSoundClassifier` 接口，后续加入 `.mlmodelc` 后直接替换。
- 事件类型包含：打鼾、咳嗽、说梦话、磨牙、环境噪音。
- 每个事件保存开始时间、结束时间、置信度、峰值分贝。

## 我的模块

功能：

- 登录入口：手机号/Apple 登录 UI 占位，第一版本地模拟登录。
- 用户协议。
- 隐私政策。
- 权限状态：麦克风、HealthKit。
- 设置：保存音频片段、识别灵敏度。
- 清除缓存：统计并清理临时文件。
- 关于应用。

## 权限配置

需要 Info.plist：

- `NSMicrophoneUsageDescription`
- `NSHealthShareUsageDescription`
- `NSHealthUpdateUsageDescription`
- `UIBackgroundModes` 包含 `audio`

需要 Capability：

- HealthKit
- Background Modes / Audio

第一版在 project 配置中加入 Info.plist 和 entitlements 文件，实际 HealthKit 能力需要在 Xcode Signing & Capabilities 中确认团队签名。

## 里程碑

### M1：工程创建

- 创建 Xcode project。
- 创建 SwiftUI App 入口。
- 完成三 Tab 基础导航。
- 配置 Info.plist、entitlements、Assets。

### M2：资源导入

- 压缩 172 张封面到 200KB 内。
- 复制 172 个 MP3。
- 生成 `sounds_manifest.json`。
- 校验资源可被 Bundle 读取。

### M3：声音模块

- 实现声音列表。
- 实现详情/播放/暂停。
- 实现收藏。
- 实现迷你播放器。

### M4：睡眠模块

- 实现录音权限和音频会话。
- 实现 SleepMonitorService。
- 实现事件分类接口与 mock 推理。
- 实现睡眠报告和 Charts。
- 接入 HealthKitService。

### M5：我的模块

- 实现登录 UI。
- 实现协议/隐私页面。
- 实现清除缓存。
- 实现权限和设置页面。

### M6：验证

- `xcodebuild` 编译通过。
- App 能读取资源、播放 MP3。
- 睡眠监测能开始/结束并生成报告。
- 清除缓存不删除 Bundle 内置资源，只清理临时/缓存目录。

## 验收标准

- 项目能在 Xcode 打开。
- iOS 17+ Simulator 编译通过。
- 首页有 3 个 Tab：声音、睡眠、我的。
- 声音 Tab 能展示导入的 Tide 声音资源。
- 封面图片单张小于 200KB。
- 睡眠 Tab 有完整监测入口、事件识别链路代码和报告 UI。
- 我的 Tab 包含登录、用户协议、隐私政策、清除缓存。
