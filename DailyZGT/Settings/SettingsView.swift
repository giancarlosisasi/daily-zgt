import KeyboardShortcuts
import SwiftUI

enum SettingsCopy {
    static let title = "Ajustes"
    static let close = "Cerrar ajustes"
    static let loginTitle = "Abrir al iniciar sesión"
    static let loginDetail = "Abre Daily ZGT cuando inicias sesión en tu Mac."
    static let loginApproval = "Falta tu aprobación en Ajustes del Sistema."
    static let loginFailed = "macOS no aceptó el cambio."
    static let openSettings = "Abrir ajustes"
    static let todayLimitTitle = "Máximo \(TodayLimit.maxOpen) prioridades abiertas en Hoy"
    static let todayLimitDetail = "Con \(TodayLimit.maxOpen) abiertas en Hoy, no puedes añadir ni mover otra a Hoy."
    static let menuBarTitleTitle = "Siguiente prioridad en la barra de menús"
    static let menuBarTitleDetail = "Muestra junto al ícono el título de la primera prioridad abierta de Hoy."
    static let shortcutTitle = "Atajo global"
    static let shortcutDetail = "Abre la ventana de captura desde cualquier app."
    static let shortcutClearedDetail = "Sin atajo: la ventana de captura no se abre desde otras apps."
}

struct SettingsHeader: View {
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: Theme.Detail.backSpacing) {
                    IconView(icon: .caretLeft, size: Theme.Detail.backChevronSize)
                    Text(SettingsCopy.title)
                        .font(Theme.Font.body)
                }
                .foregroundStyle(Theme.Detail.backText)
                .padding(.leading, Theme.Detail.backLeadingPadding)
                .padding(.trailing, Theme.Detail.backTrailingPadding)
                .frame(height: Theme.Detail.backHeight)
            }
            .buttonStyle(GhostButtonStyle(radius: Theme.Detail.backRadius))
            .accessibilityLabel(SettingsCopy.close)
            Spacer(minLength: 0)
        }
    }
}

struct LoginItemRow: View {
    let model: LoginItemSettings

    var body: some View {
        SettingsRow(title: SettingsCopy.loginTitle, detail: SettingsCopy.loginDetail) {
            SettingsToggle(title: SettingsCopy.loginTitle, isOn: model.isOn) { wantsOn in
                model.set(wantsOn)
            }
        } notes: {
            if model.needsApproval {
                SettingsNote(
                    text: SettingsCopy.loginApproval,
                    linkTitle: SettingsCopy.openSettings,
                    onLink: { model.openLoginItems() }
                )
            }
            if model.registerFailed {
                SettingsNote(text: SettingsCopy.loginFailed)
            }
        }
    }
}

struct TodayLimitRow: View {
    let isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        SettingsRow(title: SettingsCopy.todayLimitTitle, detail: SettingsCopy.todayLimitDetail) {
            SettingsToggle(title: SettingsCopy.todayLimitTitle, isOn: isOn, onChange: onChange)
        }
    }
}

struct MenuBarTitleRow: View {
    let isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        SettingsRow(title: SettingsCopy.menuBarTitleTitle, detail: SettingsCopy.menuBarTitleDetail) {
            SettingsToggle(title: SettingsCopy.menuBarTitleTitle, isOn: isOn, onChange: onChange)
        }
    }
}

struct ShortcutRow: View {
    let model: ShortcutSettings

    var body: some View {
        SettingsRow(
            title: SettingsCopy.shortcutTitle,
            detail: model.isSet ? SettingsCopy.shortcutDetail : SettingsCopy.shortcutClearedDetail
        ) {
            KeyboardShortcuts.Recorder(for: model.name, onChange: { model.shortcutDidChange($0) })
                .frame(width: Theme.Capture.recorderWidth)
        }
    }
}

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(PanelState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Detail.spacing) {
            SettingsHeader(onBack: { state.closeSettings() })
            VStack(spacing: Theme.Settings.spacing) {
                LoginItemRow(model: state.loginItem)
                TodayLimitRow(isOn: store.todayLimitIsOn) { state.setTodayLimit($0) }
                MenuBarTitleRow(isOn: store.menuBarTitleIsOn) { state.setMenuBarTitle($0) }
                ShortcutRow(model: state.shortcut)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
