import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    topPadding: Kirigami.Units.gridUnit

    property string cfg_labelPosition
    property alias  cfg_labelText: labelText.text

    Kirigami.FormLayout {

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
    }
}
