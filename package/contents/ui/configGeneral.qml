import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

Kirigami.FormLayout {
    id: page

    // Config keys from main.xml are exposed by the harness as cfg_<name>.
    // NOTE: Color keys MUST be backed by string/var here — an int property
    // silently mangles the value, which is why the colour pickers used to "not work".
    property string cfg_usageWindow

    property alias  cfg_barWidth: barWidth.value
    property alias  cfg_cornerRadius: cornerRadius.value
    property alias  cfg_borderWidth: borderWidth.value
    property string cfg_borderColor
    property string cfg_barColor
    property alias  cfg_useThresholdColors: useThresholds.checked
    property string cfg_warnColor
    property string cfg_critColor
    property alias  cfg_warnThreshold: warnThreshold.value
    property alias  cfg_critThreshold: critThreshold.value

    property string cfg_labelPosition
    property alias  cfg_labelText: labelText.text
    property alias  cfg_updateIntervalSec: updateInterval.value

    // ---- Window ------------------------------------------------------------
    // The bar reflects Anthropic's real per-plan utilisation for the chosen
    // window, so there is nothing to calibrate.

    QQC2.ComboBox {
        id: windowBox
        Kirigami.FormData.label: i18n("Show:")
        textRole: "text"
        valueRole: "value"
        model: [
            { text: i18n("Current 5-hour session"), value: "session" },
            { text: i18n("Rolling 7-day window"),   value: "weekly" }
        ]
        Component.onCompleted: currentIndex = indexOfValue(cfg_usageWindow)
        onActivated: cfg_usageWindow = currentValue
    }

    // ---- Appearance --------------------------------------------------------

    Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Appearance") }

    QQC2.SpinBox {
        id: barWidth
        Kirigami.FormData.label: i18n("Bar width:")
        from: 20
        to: 1000
        stepSize: 10
        textFromValue: (value) => value + " px"
        valueFromText: (text) => parseInt(text)
    }

    QQC2.SpinBox {
        id: cornerRadius
        Kirigami.FormData.label: i18n("Corner radius:")
        from: 0
        to: 40
        textFromValue: (value) => value + " px"
        valueFromText: (text) => parseInt(text)
    }

    QQC2.SpinBox {
        id: borderWidth
        Kirigami.FormData.label: i18n("Border width:")
        from: 0
        to: 10
        textFromValue: (value) => value + " px"
        valueFromText: (text) => parseInt(text)
    }

    KQuickControls.ColorButton {
        id: borderColor
        Kirigami.FormData.label: i18n("Border colour:")
        enabled: borderWidth.value > 0
        showAlphaChannel: true
        Component.onCompleted: color = cfg_borderColor
        onColorChanged: cfg_borderColor = color
    }

    KQuickControls.ColorButton {
        id: barColor
        Kirigami.FormData.label: i18n("Base colour:")
        showAlphaChannel: false
        Component.onCompleted: color = cfg_barColor
        onColorChanged: cfg_barColor = color
    }

    QQC2.CheckBox {
        id: useThresholds
        Kirigami.FormData.label: i18n("Colour by level:")
        text: i18n("Recolour as the bar fills up")
    }

    KQuickControls.ColorButton {
        id: warnColor
        Kirigami.FormData.label: i18n("Warning colour:")
        enabled: useThresholds.checked
        showAlphaChannel: false
        Component.onCompleted: color = cfg_warnColor
        onColorChanged: cfg_warnColor = color
    }

    QQC2.SpinBox {
        id: warnThreshold
        Kirigami.FormData.label: i18n("Warning at:")
        enabled: useThresholds.checked
        from: 0
        to: 100
        textFromValue: (value) => value + " %"
        valueFromText: (text) => parseInt(text)
    }

    KQuickControls.ColorButton {
        id: critColor
        Kirigami.FormData.label: i18n("Critical colour:")
        enabled: useThresholds.checked
        showAlphaChannel: false
        Component.onCompleted: color = cfg_critColor
        onColorChanged: cfg_critColor = color
    }

    QQC2.SpinBox {
        id: critThreshold
        Kirigami.FormData.label: i18n("Critical at:")
        enabled: useThresholds.checked
        from: 0
        to: 100
        textFromValue: (value) => value + " %"
        valueFromText: (text) => parseInt(text)
    }

    // ---- Label -------------------------------------------------------------

    Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Label") }

    QQC2.ComboBox {
        id: labelPosBox
        Kirigami.FormData.label: i18n("Position:")
        textRole: "text"
        valueRole: "value"
        model: [
            { text: i18n("Off"),        value: "off" },
            { text: i18n("On the bar"), value: "onbar" },
            { text: i18n("Left"),       value: "left" },
            { text: i18n("Right"),      value: "right" }
        ]
        Component.onCompleted: currentIndex = indexOfValue(cfg_labelPosition)
        onActivated: cfg_labelPosition = currentValue
    }

    QQC2.TextField {
        id: labelText
        Kirigami.FormData.label: i18n("Label text:")
        enabled: cfg_labelPosition !== "off"
        placeholderText: i18n("e.g. Claude (optional)")
    }

    // ---- Polling -----------------------------------------------------------

    Item { Kirigami.FormData.isSection: true }

    QQC2.SpinBox {
        id: updateInterval
        Kirigami.FormData.label: i18n("Refresh every:")
        // The usage endpoint rate-limits, so don't poll too hard (floor 1 min).
        from: 60
        to: 1800
        stepSize: 60
        textFromValue: (value) => (value / 60).toFixed(value % 60 ? 1 : 0) + " min"
        valueFromText: (text) => Math.round((parseFloat(text.replace(/[^\d.]/g, "")) || 1) * 60)
    }
}
