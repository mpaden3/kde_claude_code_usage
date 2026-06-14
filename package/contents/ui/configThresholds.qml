import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    topPadding: Kirigami.Units.gridUnit

    // NOTE: Color keys MUST be backed by string/var here — an int property
    // silently mangles the value, which is why the colour pickers used to "not work".
    property alias  cfg_useThresholdColors: useThresholds.checked
    property string cfg_warnColor
    property string cfg_critColor
    property alias  cfg_warnThreshold: warnThreshold.value
    property alias  cfg_critThreshold: critThreshold.value

    Kirigami.FormLayout {

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
    }
}
