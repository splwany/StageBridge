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
            Text("台前随屏").font(.system(size: 25, weight: .semibold))
            Text("StageByScreen · 台前调度随屏切换")
              .foregroundStyle(.secondary)
          }
          Spacer()
          Text(
            Bundle.main.object(forInfoDictionaryKey: "StageByScreenReleaseVersion") as? String
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
          Text("外接屏时关闭台前调度，让多个窗口自由并排；单独使用笔记本时开启，让工作更专注。")
            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
          Text("连接变化稳定 2 秒后切换；连接状态不变时保留你的手动设置。")
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
        DisclosureGroup("高级设置") {
          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Text("备用检查间隔")
              Spacer()
              Picker(
                "备用检查间隔",
                selection: Binding(get: { monitor.interval }, set: { monitor.setInterval($0) })
              ) {
                ForEach(DisplayMonitor.intervals, id: \.self) {
                  Text("\($0 / 60) 分钟").tag($0)
                }
              }.labelsHidden().frame(width: 115)
            }
            Text("默认 5 分钟。仅用于补查可能遗漏的系统通知，不影响正常插拔时的切换速度。")
              .font(.caption).foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }.padding(.top, 10)
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
