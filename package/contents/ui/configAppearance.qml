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
    property alias  cfg_barWidth: barWidth.value
    property alias  cfg_cornerRadius: cornerRadius.value
    property alias  cfg_borderWidth: borderWidth.value
    property string cfg_borderColor
    property string cfg_barColor

    Kirigami.FormLayout {

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
    }
}
