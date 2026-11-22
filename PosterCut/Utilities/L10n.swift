import Foundation

/// Centralized strict multi-language localization backed by `Localizable.xcstrings` (15 languages).
enum L10n {
    static func tr(_ key: String, fallback: String? = nil) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: fallback ?? key, comment: "")
    }

    static func fmt(_ key: String, _ args: CVarArg...) -> String {
        let format = tr(key)
        return String(format: format, locale: Locale.current, arguments: args)
    }

    static func paperName(_ preset: PaperPreset) -> String {
        tr(preset.labelKey)
    }

    static func rowCol(_ row: Int, _ col: Int) -> String {
        fmt("map_row_col_fmt", row, col)
    }
}
