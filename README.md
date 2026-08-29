<div align="center">
  <img src="entry/src/main/resources/base/media/heszel_store_icon_1024.png" width="96" alt="Heszel 图标">
  <h1>Heszel</h1>
  <p><strong>轻巧的服务器资源看板</strong></p>
  <p>专为 HarmonyOS 打造的 Beszel 监控客户端</p>
  <p>简体中文 · <a href="README.en.md">English</a></p>
</div>

<p align="center">
  <img src="docs/screenshots/dashboard-tablet.png" width="840" alt="Heszel 平板界面">
</p>

## 简介

Heszel 是一款专为 HarmonyOS 设备打造的 [Beszel](https://beszel.dev/) 监控客户端。连接自己的 Beszel Hub 后，可以在手机、平板或折叠屏上集中查看所有服务器的运行状态和资源用量。

Heszel 专注于移动端监控体验，本身不包含 Beszel Hub、Agent 或 Iroh 网关。使用前需要先部署 Beszel，并将需要监控的系统添加到 Hub；如需通过 Iroh 连接，还需单独部署 [iroh-heszel](https://github.com/134ARG/iroh-heszel) 提供的 Linux 网关。

## 主要功能

- **集中查看系统状态**：在一个列表中查看在线状态、CPU、内存、磁盘和温度，快速发现异常系统。
- **丰富的资源详情**：展示 CPU 历史趋势与各核心用量、内存、Swap、ZFS ARC、文件系统、磁盘 I/O、平均负载、温度、运行时间等数据。
- **GPU 与容器监控**：查看 GPU 使用率、显存和功耗，以及 Docker / Podman 容器的 CPU、内存和网络流量。
- **网络与服务状态**：查看网卡实时速率、累计流量、systemd 服务状态和主机传感器数据。
- **磁盘健康信息**：集中展示 SATA、NVMe 等设备的 S.M.A.R.T. 健康状态、关键指标与完整属性。
- **实时指标**：支持实时刷新，并可选择滚动页面时是否继续更新，以平衡流畅度与耗电。
- **桌面服务卡片**：无需打开应用即可查看常用系统的 CPU、内存、磁盘、温度、负载、网络和磁盘 I/O；支持切换系统与手动刷新。
- **HarmonyOS 自适应设计**：适配手机、平板和折叠屏，在大屏设备上使用分栏布局。
- **个性化显示**：支持浅色、深色和跟随系统模式，提供中文与英文界面，并可调节 CPU 图表高度。
- **安全保存连接信息**：登录密码不会被保存；会话和连接密钥使用 HarmonyOS 提供的安全能力保护。

> 实际可显示的数据取决于 Beszel Hub、Agent 版本、服务器硬件和 Agent 配置。

## 连接方式

| 方式 | 说明 |
| --- | --- |
| HTTP 直连 | 使用 Beszel Hub 地址登录；也支持可选的 Heszel 网关访问密钥。 |
| Iroh | 扫描 [iroh-heszel](https://github.com/134ARG/iroh-heszel) Linux 网关提供的配对二维码，通过直连地址或中继连接 Hub。Beszel 账户凭据与 Iroh 配对信息分开保存。 |

## 界面预览

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/dashboard-phone.png" width="260" alt="系统列表"></td>
    <td align="center"><img src="docs/screenshots/overview-phone.png" width="260" alt="资源总览"></td>
    <td align="center"><img src="docs/screenshots/details-phone.png" width="260" alt="GPU 与容器详情"></td>
  </tr>
  <tr>
    <td align="center">系统列表</td>
    <td align="center">资源总览</td>
    <td align="center">GPU 与容器</td>
  </tr>
</table>

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/smart-phone.png" width="300" alt="磁盘 S.M.A.R.T. 详情"></td>
    <td align="center"><img src="docs/screenshots/widget-phone.png" width="300" alt="HarmonyOS 桌面服务卡片"></td>
  </tr>
  <tr>
    <td align="center">磁盘健康与 S.M.A.R.T. 属性</td>
    <td align="center">桌面服务卡片</td>
  </tr>
</table>

## 使用前准备

1. 部署并配置 [Beszel Hub 与 Agent](https://beszel.dev/guide/getting-started)。
2. 准备一个可以访问目标系统的 Beszel 账户。
3. 确保 HarmonyOS 设备可以访问 Hub；如需通过 Iroh 连接，请部署 [iroh-heszel](https://github.com/134ARG/iroh-heszel) Linux 网关并准备配对二维码。

## 许可证

本项目采用 [GNU 通用公共许可证第 3 版](LICENSE)（GPL-3.0-only）。
