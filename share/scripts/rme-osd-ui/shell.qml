import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
ShellRoot {
 id: root
 property real db: -114.5
 property bool active: false
 property real fraction: Math.max(0, Math.min(1, (db + 114.5) / 99.5))
 Timer { id: hideTimer; interval: 1600; onTriggered: root.active = false }
 Timer { id: exitTimer; interval: 20000; running: true; onTriggered: Qt.quit() }
 IpcHandler {
  target: "rme"
  function displayVolume(value: string): void {
   const level = Number(value.replace("db:", ""));
   if (!isFinite(level) || level < -114.5 || level > 6) return;
   root.db = level; root.active = true; hideTimer.restart(); exitTimer.restart();
  }
  function pulse(): void { if(root.active || root.db > -114.5) { root.active=true; hideTimer.restart(); exitTimer.restart(); } }
  function status(): string { return root.db.toFixed(1) + " dB · " + Math.round(root.fraction*100) + "%"; }
 }
 PanelWindow {
  // No edge anchors: layer-shell centers the card on both axes.
  implicitWidth: 390; implicitHeight: 155
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  focusable: false
  WlrLayershell.namespace: "rme-volume-osd"
  WlrLayershell.layer: WlrLayer.Overlay
  mask: Region {}
  visible: root.active || card.opacity > 0
  Rectangle {
   id: card
   anchors.fill: parent; anchors.margins: 6
   radius: 25; color: "#ed101214"
   border.color: root.db >= -15 ? "#ffaa00" : "#55473a"
   border.width: 1
   opacity: root.active ? 1 : 0
   Behavior on opacity { NumberAnimation { duration: 180 } }
   Text { x: 23; y: 18; text: "🎧  RME / LINE OUT"; color: "#d5c9b8"; font.pixelSize: 13; font.letterSpacing: 1 }
   Text { x: 23; y: 42; text: root.db.toFixed(1) + " dB"; color: "#fff3db"; font.pixelSize: 29; font.weight: Font.DemiBold }
   Text { anchors.right: parent.right; anchors.rightMargin: 24; y: 47; text: Math.round(root.fraction*100) + "%"; color: "#ffad19"; font.pixelSize: 23; font.weight: Font.DemiBold }
   Rectangle {
    x: 24; y: 88; width: parent.width-48; height: 7; radius: 4; color: "#34302b"
    Rectangle { width: parent.width*root.fraction; height: 7; radius: 4
     gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: "#ff6500" } GradientStop { position: 1; color: "#ffbb20" } }
     Behavior on width { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
    }
   }
   Text { x: 24; y: 110; text: "RECORRIDO EN dB"; color: "#9a9186"; font.pixelSize: 10; font.letterSpacing: 1 }
   Text { anchors.right: parent.right; anchors.rightMargin: 24; y: 109; text: "TECHO  −15 dB"; color: "#d5a75b"; font.pixelSize: 11 }
  }
 }
}
