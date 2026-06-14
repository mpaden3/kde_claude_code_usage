import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "configure"
        source: "configGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Appearance")
        icon: "draw-rectangle"
        source: "configAppearance.qml"
    }
    ConfigCategory {
        name: i18n("Thresholds")
        icon: "color-management"
        source: "configThresholds.qml"
    }
    ConfigCategory {
        name: i18n("Label")
        icon: "format-text-rich"
        source: "configLabel.qml"
    }
}
