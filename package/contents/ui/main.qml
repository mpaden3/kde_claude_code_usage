import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // Absolute path to the bundled collector binary (strip the file:// scheme).
    // It calls Anthropic's usage endpoint via the Claude Code OAuth token and
    // reports the *real* per-plan utilisation, so there is no guessed limit.
    readonly property string collectorPath:
        Qt.resolvedUrl("../code/claude-usage-collector").toString().replace(/^file:\/\//, "")

    property var usage: ({})
    property real utilization: 0    // raw percent from Anthropic (may exceed 100)
    property real fraction: 0       // 0..1, the bar fill (clamped utilization)
    property bool active: false
    property int minutesRemaining: 0
    property int minutesElapsed: 0

    readonly property string usageWindow: plasmoid.configuration.usageWindow
    readonly property bool weekly: usageWindow === "weekly"

    property double lastRefreshMs: 0

    function refresh() {
        // Debounce: the endpoint rate-limits, so ignore bursts (e.g. double
        // clicks) within a few seconds of the previous run.
        const now = Date.now();
        if (now - lastRefreshMs < 3000)
            return;
        lastRefreshMs = now;
        executable.exec("'" + collectorPath + "' " + usageWindow);
    }

    function handleData(stdout) {
        let d;
        try {
            d = JSON.parse(stdout);
        } catch (e) {
            // Empty/garbled output: keep the last good reading rather than blank.
            root.usage = { error: "parse error: " + e };
            return;
        }
        root.usage = d;
        // Transient failure with nothing cached to fall back on: keep the last
        // reading on screen instead of blanking the bar.
        if (d.error && !d.active)
            return;
        root.active = !!d.active;
        root.utilization = d.utilization || 0;
        root.minutesRemaining = d.minutes_remaining || 0;
        root.minutesElapsed = d.minutes_elapsed || 0;
        root.fraction = root.active ? Math.max(0, Math.min(1, d.fraction || 0)) : 0;
    }

    // Switching session <-> weekly re-reads immediately.
    onUsageWindowChanged: refresh()

    // The text shown in the label, e.g. "Claude 54%" or just "54%".
    readonly property string labelString: {
        const pct = root.active ? Math.round(root.utilization) + "%" : "–";
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
        interval: Math.max(60, plasmoid.configuration.updateIntervalSec) * 1000
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
                const pct = root.utilization;
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
        const u = root.usage || {};
        if (!root.active)
            return u.error ? i18n("Error: %1", u.error)
                 : (root.weekly ? i18n("No 7-day usage reported.")
                                : i18n("No active 5-hour session."));
        const head = root.weekly
            ? i18n("%1%% of your 7-day limit", Math.round(root.utilization))
            : i18n("%1%% of your 5-hour limit", Math.round(root.utilization));
        const h = Math.floor(root.minutesRemaining / 60);
        const m = root.minutesRemaining % 60;
        const reset = h > 0 ? i18n("Resets in %1 h %2 min", h, m)
                            : i18n("Resets in %1 min", m);
        const stale = u.stale ? "\n" + i18n("Last known value — refresh failed (rate limited).") : "";
        return head + "\n" + reset + stale;
    }
}
