<p align="center"><img width="120" src="https://www.fyscu.com/img/logo-blue.png" alt="Feiyang Club Logo"></p>

# 云上飞扬 (Feiyang on Cloud)

<p align="center">
  <img alt="platform" src="https://img.shields.io/badge/platform-iOS%20%7C%20Android%20%7C%20macOS-blue" />
  <img alt="flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" />
  <img alt="dart" src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart" />
  <img alt="license" src="https://img.shields.io/badge/license-private-lightgrey" />
</p>

> 四川大学飞扬俱乐部

**云上飞扬**是飞扬俱乐部为全校师生打造的设备报修服务平台。本项目是从微信小程序向 Flutter 跨平台重构的全新客户端，在保留原有全部业务能力的基础上，提供了更流畅的原生体验。

## 功能特性

**🛠 设备报修**
- 引导式报修表单：设备信息、故障描述、故障图片上传等
- 工单全流程可视化：报修 → 技术员接单 → 双向确认 → 完成/取消
- 报修须知强制确认、跨校区维修意愿、进度短信/邮件通知

**🧰 技术员工作台**
- 扫码接单 / 转单码接单
- 维修凭证拍照上传，双向确认闭环，异常工单强制关闭
- 接单意愿、多校区接单、同时接单上限管理
- 技术员英雄榜与年度维修总结

**🎪 社团活动**
- 现场活动幸运抽奖号码与中奖状态展示

**🔐 账号体系**
- 手机号 + 短信验证码登录，30 天长效会话
- 与微信小程序同账号互通
- 资料编辑、头像上传、换绑手机号、账号注销

## 技术栈

| 类别 | 选型 |
|---|---|
| 框架 | Flutter 3.x|
| 状态管理 | Provider (`ChangeNotifier`) |
| 网络层 | Dio 5.x（Bearer 注入、401 自动登出、错误防御） |
| 扫码/二维码 | mobile_scanner · qr_flutter |
| 本地存储 | shared_preferences |

## 项目结构

```
lib/
├── core/          # 网络层、接口常量、主题
├── models/        # 数据实体与序列化
├── services/      # RESTful API 交互
├── providers/     # 业务状态管理
└── views/         # 页面（首页 / 活动 / 我的 Tab + 子页面）
```

## 快速开始

```bash
git clone https://github.com/gkxqh/foc_app.git
cd foc_app
flutter pub get

flutter run -d macos    # 桌面预览（macOS）
flutter run             # 连接 iOS / Android 真机或模拟器
```

> 后端接口基址：`https://focapi.feiyang.ac.cn`
> 登录需要已在微信小程序「云上飞扬」注册并绑定手机号的账号。

## 相关项目

- [fyscu/foc_fe](https://github.com/fyscu/foc_fe) — 微信小程序

---

Powered By [四川大学飞扬俱乐部研发部](https://lab.feiyang.ac.cn/)
