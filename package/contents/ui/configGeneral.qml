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
    property string cfg_plan
    property string cfg_usageWindow
    property alias  cfg_tokenLimit: tokenLimit.value
    property alias  cfg_weeklyTokenLimit: weeklyLimit.value
    property string cfg_metric

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

    // Full-bar token budgets per plan. Claude doesn't expose the real ceiling
    // locally, so these are calibrated against Claude's own usage %: Pro was
    // tuned so the bar matches the official meter (session ~76%, weekly ~52%).
    // Max tiers scale Pro by 5×/20×. "Custom" lets you override either field.
    readonly property var planPresets: ({
        "pro":   { session: 860000,    weekly: 8000000 },
        "max5":  { session: 4300000,   weekly: 40000000 },
        "max20": { session: 17200000,  weekly: 160000000 }
    })

    // ---- Plan & window -----------------------------------------------------

    QQC2.ComboBox {
        id: planBox
        Kirigami.FormData.label: i18n("Plan:")
        textRole: "text"
        valueRole: "value"
        model: [
            { text: i18n("Pro"),         value: "pro" },
            { text: i18n("Max (5×)"),    value: "max5" },
            { text: i18n("Max (20×)"),   value: "max20" },
            { text: i18n("Custom"),      value: "custom" }
        ]
        Component.onCompleted: currentIndex = indexOfValue(cfg_plan)
        onActivated: {
            cfg_plan = currentValue;
            const p = page.planPresets[currentValue];
            if (p) {
                cfg_tokenLimit = p.session;
                cfg_weeklyTokenLimit = p.weekly;
            }
        }
    }

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

    QQC2.SpinBox {
        id: tokenLimit
        Kirigami.FormData.label: i18n("Session full bar at:")
        enabled: cfg_plan === "custom"
        from: 1000
        to: 1000000000
        stepSize: 50000
        editable: true
        textFromValue: (value) => value.toLocaleString(Qt.locale(), "f", 0) + " tokens"
        valueFromText: (text) => parseInt(text.replace(/\D/g, "")) || from
    }

    QQC2.SpinBox {
        id: weeklyLimit
        Kirigami.FormData.label: i18n("Weekly full bar at:")
        enabled: cfg_plan === "custom"
        from: 1000
        to: 2000000000
        stepSize: 500000
        editable: true
        textFromValue: (value) => value.toLocaleString(Qt.locale(), "f", 0) + " tokens"
        valueFromText: (text) => parseInt(text.replace(/\D/g, "")) || from
    }

    QQC2.ComboBox {
        id: metricBox
        Kirigami.FormData.label: i18n("Count:")
        textRole: "text"
        valueRole: "value"
        model: [
            { text: i18n("Billable tokens (input + output + cache writes)"), value: "billable" },
            { text: i18n("All tokens (includes cache reads)"), value: "total" }
        ]
        Component.onCompleted: currentIndex = indexOfValue(cfg_metric)
        onActivated: cfg_metric = currentValue
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
        from: 5
        to: 600
        stepSize: 5
        textFromValue: (value) => value + " s"
        valueFromText: (text) => parseInt(text)
    }
}
