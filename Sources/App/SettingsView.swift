import ServiceManagement
import SwiftUI

struct SettingsView: View {
  @ObservedObject var monitor: DisplayMonitor
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        HStack(alignment: .top) {
          Image(systemName: "display.2").font(.system(size: 30)).foregroundStyle(.blue)
          VStack(alignment: .leading, spacing: 5) {
            Text("StageBridge").font(.system(size: 25, weight: .semibold))
            Text("外接屏与台前调度，自动配合。")
              .foregroundStyle(.secondary)
          }
          Spacer()
          Text(
            Bundle.main.object(forInfoDictionaryKey: "StageBridgeReleaseVersion") as? String
              ?? "开发版本"
          ).font(.caption).foregroundStyle(.secondary)
        }
        VStack(alignment: .leading, spacing: 16) {
          HStack {
            Circle().fill(monitor.enabled ? Color.green : .gray).frame(width: 8, height: 8)
            Text(monitor.enabled ? "自动切换已开启" : "自动切换已暂停").fontWeight(.medium)
            Spacer()
            Text(monitor.displayStatus).font(.caption).foregroundStyle(.secondary)
          }
          Divider()
          Toggle("启用自动切换", isOn: Binding(get: { monitor.enabled }, set: { monitor.setEnabled($0) }))
            .disabled(monitor.hasLegacy)
          Text("连接外接显示器时关闭台前调度；断开时开启。连接状态不变时，尊重你的手动切换。")
            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
          HStack {
            Text("备用检查间隔")
            Spacer()
            Picker(
              "备用检查间隔",
              selection: Binding(get: { monitor.interval }, set: { monitor.setInterval($0) })
            ) {
              ForEach(DisplayMonitor.intervals, id: \.self) { Text("\($0) 秒").tag($0) }
            }.labelsHidden().frame(width: 115)
          }
          Text("优先响应系统显示器事件，稳定 2 秒后切换。备用间隔修改立即生效。")
            .font(.caption).foregroundStyle(.secondary)
          Divider()
          Toggle(
            "登录时启动",
            isOn: Binding(
              get: { monitor.loginEnabled || monitor.loginNeedsApproval },
              set: { monitor.setLogin($0) }))
          if monitor.loginNeedsApproval {
            Button("在系统设置中允许登录启动") { SMAppService.openSystemSettingsLoginItems() }
          }
        }
        .padding(18)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
        if monitor.hasLegacy {
          VStack(alignment: .leading, spacing: 8) {
            Text("发现旧版 Python 监听器。迁移会停用并备份旧文件，再接管设置。")
              .font(.caption)
            Button(monitor.migrating ? "正在迁移…" : "迁移旧版监听器") { monitor.migrateLegacy() }
              .disabled(monitor.migrating)
          }
        }
        Label("测试版通过系统内部偏好切换台前调度，切换时会重载 Dock。macOS 升级后可能失效。", systemImage: "info.circle")
          .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        if let attention = monitor.attention {
          VStack(alignment: .leading, spacing: 8) {
            Label("需要检查", systemImage: "exclamationmark.triangle.fill")
              .foregroundStyle(.orange)
            Text(attention).font(.caption).textSelection(.enabled)
              .fixedSize(horizontal: false, vertical: true)
            Button("已了解") { monitor.dismissAttention() }
          }
          .padding(12)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
        Text(monitor.lastAction).font(.caption).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        HStack {
          Button("查看日志") { NSWorkspace.shared.open(monitor.logURL) }
          Spacer()
          Text("关闭窗口后继续在菜单栏运行").font(.caption).foregroundStyle(.secondary)
        }
      }
      .padding(24).frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(width: 568, height: 520)
    .alert(
      "需要注意",
      isPresented: Binding(
        get: { monitor.errorMessage != nil }, set: { if !$0 { monitor.errorMessage = nil } })
    ) {
      Button("好") { monitor.errorMessage = nil }
    } message: {
      Text(monitor.errorMessage ?? "")
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    { _ in monitor.refreshLogin() }
  }
}
