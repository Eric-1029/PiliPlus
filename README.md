<div align="center">
  <img width="180" height="180" src="assets/images/logo/logo.png" alt="PiliPlus">
  <h1>PiliPlus</h1>
  <p>使用 Flutter 开发的第三方 Bilibili 客户端</p>

  [![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
  [![Android](https://img.shields.io/badge/Android-supported-brightgreen.svg)](#平台支持)
  [![GitHub release](https://img.shields.io/github/v/release/Eric-1029/PiliPlus)](https://github.com/Eric-1029/PiliPlus/releases)
</div>

> 本仓库是 [bggRGjQaUbCoE/PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)
> 的修改版。新增的 Android 原生播放加速器以
> [bilibili-accelerator v0.3.0 / commit 208cce9](https://github.com/realzza/bilibili-accelerator/tree/208cce947ed92ae8a6b0d03d930deb45a9dc39d5)
> 为功能基线进行 Dart/Flutter 移植。

## 播放加速

Android 版本内置原生播放线路加速器，用于识别并避开 PCDN、MCDN、异常端口及已知慢节点。实现不依赖浏览器扩展、脚本注入或 WebRTC 上传。

- 自动并行测速与固定服务器选线
- “仅修复慢节点”“强制切换”“关闭”三种模式
- MCDN 全部代理、仅资源接口代理或直接换域名
- PCDN、海外镜像、异常端口及可选 Akamai 识别
- 视频、音频、番剧、durl、直播、下载和投屏统一解析
- 2.5 秒卡顿检测、候选线路轮换和原位置恢复
- 实时速度、峰值、缓存曲线、节点及恢复统计
- 脱敏诊断报告，不记录媒体签名和完整 URL

入口位于“设置 → 音视频设置 → 播放加速”，播放器的“更多设置”中也提供实时状态面板。

升级旧版本后，原 CDN 选项会迁移为“加速开启 + 自动选线”。iOS、Windows、Linux 和 macOS 不显示加速设置，直接使用服务端首选媒体 URL。

## 其他功能

- 视频、番剧、直播与音频播放
- 弹幕、字幕、倍速、画中画和后台播放
- 离线缓存、DLNA 投屏和 WebDAV 设置备份
- 动态、评论、收藏、稍后再看和多账号
- Android、iOS、Windows、Linux 与 macOS 界面适配

完整功能会随上游 PiliPlus 持续演进。

## 平台支持

| 平台 | 客户端 | 播放加速 |
| --- | --- | --- |
| Android | 支持 | 完整支持 |
| iOS / iPadOS | 支持 | 不启用 |
| Windows | 支持 | 不启用 |
| Linux | 支持 | 不启用 |
| macOS | 支持 | 不启用 |

## 下载与构建

预构建 APK 可从 [Releases](https://github.com/Eric-1029/PiliPlus/releases) 下载。

本地构建需要 Flutter 稳定版以及可用的 Android SDK：

```bash
flutter pub get
flutter test
flutter build apk --release --split-per-abi
```

## 开源协议

PiliPlus 及本修改版整体依据 [GNU General Public License v3.0](LICENSE) 发布。分发 APK 时，对应源代码通过本仓库同一 Release 标签公开。

播放加速规则与策略移植自 `realzza/bilibili-accelerator`：

- 基线版本：v0.3.0
- 固定提交：`208cce947ed92ae8a6b0d03d930deb45a9dc39d5`
- 原项目协议：MIT
- 原版权声明：Copyright © 2026 realzza

MIT 版权和许可原文见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。本项目对移植代码所作的修改与原项目作者无关。

## 声明

本项目仅供学习、研究和个人测试，不隶属于或代表哔哩哔哩。项目不提供破解内容；使用者应遵守所在地法律、平台服务条款和内容版权要求。

本软件按 GPL‑3.0 “原样”提供，不附带任何明示或暗示担保。

## 致谢

- [bggRGjQaUbCoE/PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)
- [guozhigq/pilipala](https://github.com/guozhigq/pilipala)
- [orz12/PiliPalaX](https://github.com/orz12/PiliPalaX)
- [realzza/bilibili-accelerator](https://github.com/realzza/bilibili-accelerator)
- [SocialSisterYi/bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)
- [media-kit](https://github.com/media-kit/media-kit)
- [dio](https://pub.dev/packages/dio)
