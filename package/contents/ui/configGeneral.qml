import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// SimpleKCM (a Kirigami.ScrollablePage) is the idiomatic config-page root: it
// gives the page proper padding so the form no longer sticks to the top edge,
// and scrolls if a page ever outgrows the dialog.
KCM.SimpleKCM {
    id: page

    // A little extra breathing room above the first row (default is only ~6px).
    topPadding: Kirigami.Units.gridUnit

    // Config keys from main.xml are exposed by the harness as cfg_<name>.
    // Each page only declares the keys it actually uses; they all bind to the
    // same underlying config object, so values stay consistent across tabs.
    property string cfg_usageWindow
    property alias  cfg_updateIntervalSec: updateInterval.value

    Kirigami.FormLayout {

        // ---- Window --------------------------------------------------------
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

        // ---- Polling -------------------------------------------------------

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
}
