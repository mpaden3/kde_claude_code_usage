import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // Absolute path to the bundled helper script (strip the file:// scheme).
    readonly property string scriptPath:
        Qt.resolvedUrl("../code/claude_usage.py").toString().replace(/^file:\/\//, "")

    property var usage: ({})
    property int tokens: 0
    property real fraction: 0       // 0..1, only meaningful while usage is active
    property bool active: false
    property int minutesRemaining: 0

    readonly property string usageWindow: plasmoid.configuration.usageWindow
    readonly property bool weekly: usageWindow === "weekly"
    readonly property int limit: Math.max(1,
        weekly ? plasmoid.configuration.weeklyTokenLimit
               : plasmoid.configuration.tokenLimit)

    function chosenTokens(d) {
        if (!d)
            return 0;
        if (plasmoid.configuration.metric === "total")
            return (d.total_tokens || 0);
        return (d.input_tokens || 0) + (d.output_tokens || 0) + (d.cache_creation_tokens || 0);
    }

    function refresh() {
        executable.exec("python3 '" + scriptPath + "' " + usageWindow);
    }

    function handleData(stdout) {
        try {
            const d = JSON.parse(stdout);
            root.usage = d;
            root.active = !!d.active;
            root.minutesRemaining = d.minutes_remaining || 0;
            root.tokens = chosenTokens(d);
            root.fraction = root.active ? Math.max(0, Math.min(1, root.tokens / root.limit)) : 0;
        } catch (e) {
            root.usage = { error: "parse error: " + e };
            root.active = false;
            root.fraction = 0;
        }
    }

    // Switching session <-> weekly (or its limit) re-reads immediately.
    onUsageWindowChanged: refresh()

    // The text shown in the label, e.g. "Claude 54%" or just "54%".
    readonly property string labelString: {
        const pct = root.active ? Math.round(root.fraction * 100) + "%" : "–";
        const t = plasmoid.configuration.labelText;
        return (t && t.length) ? (t + " " + pct) : pct;
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            executable.disconnectSource(source); // run-once per tick
            root.handleData(data["stdout"] || "");
        }
        function exec(cmd) {
            connectSource(cmd);
        }
    }

    Timer {
        interval: Math.max(5, plasmoid.configuration.updateIntervalSec) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Always show the bar itself in the panel, never a generic icon.
    preferredRepresentation: fullRepresentation

    fullRepresentation: RowLayout {
        id: rep
        spacing: Kirigami.Units.smallSpacing

        readonly property int barW: Math.max(20, plasmoid.configuration.barWidth)
        readonly property string labelPos: plasmoid.configuration.labelPosition
        readonly property color fillColor: {
            if (plasmoid.configuration.useThresholdColors) {
                const pct = root.fraction * 100;
                if (pct >= plasmoid.configuration.critThreshold)
                    return plasmoid.configuration.critColor;
                if (pct >= plasmoid.configuration.warnThreshold)
                    return plasmoid.configuration.warnColor;
            }
            return plasmoid.configuration.barColor;
        }

        QQC2.Label {
            visible: rep.labelPos === "left"
            Layout.alignment: Qt.AlignVCenter
            text: root.labelString
        }

        Item {
            id: bar
            Layout.preferredWidth: rep.barW
            Layout.minimumWidth: rep.barW
            Layout.maximumWidth: rep.barW
            Layout.fillHeight: true

            Rectangle {
                id: track
                anchors.fill: parent
                anchors.topMargin: Kirigami.Units.smallSpacing
                anchors.bottomMargin: Kirigami.Units.smallSpacing
                radius: plasmoid.configuration.cornerRadius
                color: Qt.rgba(0, 0, 0, 0.25)
                border.width: plasmoid.configuration.borderWidth
                border.color: plasmoid.configuration.borderColor

                readonly property int inset: Math.max(1, border.width)

                Rectangle {
                    id: fill
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: track.inset
                    radius: Math.max(0, track.radius - track.inset)
                    width: Math.max(0, (parent.width - 2 * track.inset) * root.fraction)
                    color: rep.fillColor
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 300 } }
                }

                QQC2.Label {
                    anchors.centerIn: parent
                    visible: rep.labelPos === "onbar"
                    text: root.labelString
                    font.pixelSize: Math.max(8, Math.round(parent.height * 0.5))
                    color: "white"
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.6)
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onClicked: root.refresh() // click to force an immediate refresh
                }
            }
        }

        QQC2.Label {
            visible: rep.labelPos === "right"
            Layout.alignment: Qt.AlignVCenter
            text: root.labelString
        }
    }

    toolTipMainText: i18n("Claude Usage")
    toolTipSubText: {
        if (root.usage && root.usage.error)
            return i18n("Error: %1", root.usage.error);
        if (!root.active)
            return root.weekly ? i18n("No usage recorded in the last 7 days.")
                               : i18n("No active 5-hour session.");
        const head = i18n("%1 tokens · %2%% of limit",
                          root.tokens.toLocaleString(Qt.locale(), "f", 0),
                          Math.round(root.fraction * 100));
        return root.weekly
            ? head + "\n" + i18n("Window started %1 min ago", root.usage.minutes_elapsed || 0)
            : head + "\n" + i18n("%1 min left in this session", root.minutesRemaining);
    }
}
