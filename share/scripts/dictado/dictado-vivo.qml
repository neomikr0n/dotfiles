// dictado-vivo.qml, la capa del dictado en vivo (wlr-layer-shell sobre Quickshell).
//
// QUÉ ES
// ======
// Una tira fina abajo, centrada, que muestra lo que el micrófono está captando mientras
// dictas. La dibuja Quickshell, que en Wayland crea una CAPA (wlr-layer-shell), no una
// ventana: por eso la transparencia es real y no un velo de un toolkit.
//
// TRES ESTADOS
// ============
//   escuchando      el micrófono está abierto y todavía no se reconoció nada.
//                   Punto que late y barra de nivel viva.
//   transcribiendo  hay texto en curso. La hipótesis parcial va en gris, porque cambia con
//                   cada pasada de la ventana deslizante, y la última palabra en blanco.
//                   Este estado cubre también la pasada final. Mientras el puente
//                   transcribe el audio guardado, la última hipótesis sigue en pantalla y
//                   eso es la verdad de ese momento. No se marca "listo" hasta que el texto
//                   final existe.
//   listo           la transcripción final está lista. Texto en blanco y punto verde.
//   error           no se pudo arrancar o no se reconoció nada. Texto en rojo.
//
// DE DÓNDE SACA EL ESTADO
// =======================
// De estado.json, que escribe dictado-vivo.py y, al final, dictado-vivo.sh. Se lee con
// FileView en modo vigilado, así que la capa NO sondea. Reacciona al cambio del fichero. El
// fichero se escribe con reemplazo atómico (escribir .tmp y renombrar), así que el lector
// nunca ve un JSON a medias.
//
// EL FOCO NO SE TOCA, Y ESTO ES LO QUE NO HAY QUE ROMPER
// =====================================================
// WlrKeyboardFocus.None. Si la capa cogiera el teclado, el destino del pegado dejaría de ser
// la ventana donde estabas escribiendo y el texto no llegaría a ninguna parte. Es el fallo
// clásico de este tipo de HUD y aquí está apagado a propósito. Medido el 2026-10-10: con la
// capa arriba, la ventana de debajo conserva el foco y el pegado aterriza donde debe.
//
// TRANSPARENCIA
// =============
// `color: "transparent"` en el PanelWindow y la opacidad en un Item hijo. QWindow::opacity no
// está implementado en Wayland; la opacidad de un QQuickItem sí (es un nodo del scene graph).
// Mismo camino que jwa-timer.qml, que ya está medido en esta máquina.
//
// POSICIÓN
// ========
// Solo se ancla abajo. Al no anclar left ni right, wlr-layer-shell centra la superficie en
// horizontal, que es justo lo que quiere un HUD de subtítulo. Si se anclaran las dos, la
// superficie se estiraría a todo el ancho (lo dice la documentación de PanelWindow) y la tira
// transparente se comería los clics de toda esa franja.
//
// CLIC PARA PARAR
// ===============
// Un clic en la pastilla llama a dictado-vivo.sh parar. La capa no tiene teclado, así que el
// ratón es la única entrada que puede ofrecer, y parar sin soltar el teclado es útil.

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

ShellRoot {
    id: raiz

    // --- De dónde sale el estado -------------------------------------------
    // El directorio de trabajo se resuelve igual que en dictado-vivo.sh. Si el puente pasa
    // DICTADO_VIVO_RUNTIME, manda eso; si no, se repite la regla por defecto.
    readonly property string runtime: {
        var d = Quickshell.env("DICTADO_VIVO_RUNTIME")
        if (d && d.length > 0) return d
        var x = Quickshell.env("XDG_RUNTIME_DIR")
        if (x && x.length > 0) return x + "/dictado-vivo"
        return "/tmp/dictado-vivo"
    }

    property string estado: "escuchando"
    property string texto: ""
    property real nivel: 0.0

    FileView {
        id: vista
        path: raiz.runtime + "/estado.json"
        watchChanges: true
        blockLoading: true
        printErrors: false
        // watchChanges solo EMITE fileChanged; no recarga por su cuenta. Sin esta línea la
        // capa se queda con el primer estado que leyó para siempre. Medido el 2026-10-10: con
        // el reload() fuera, los tres estados se dibujaban idénticos.
        onFileChanged: vista.reload()
        onTextChanged: raiz.leer()
    }

    function leer() {
        try {
            var t = vista.text()
            if (!t || t.length === 0) return
            var o = JSON.parse(t)
            if (typeof o.estado === "string" && o.estado.length > 0) raiz.estado = o.estado
            if (typeof o.texto === "string") raiz.texto = o.texto
            if (typeof o.nivel === "number") raiz.nivel = Math.max(0, Math.min(1, o.nivel))
        } catch (e) { }
    }

    // --- Paleta -------------------------------------------------------------
    // El fondo de la pastilla lleva el alfa en el propio color (f0 = 94 %), no en la opacidad
    // del Item. Medido el 2026-10-10: con el alfa a 0 la pastilla desaparece y se ve el fondo
    // tal cual, así que el compositor respeta el alfa; no hace falta el truco doble. Al 94 %
    // el fondo se intuye pero no compite con el texto, que es lo que se tiene que leer.
    readonly property color colorFondo:  "#f0121317"
    readonly property color colorGris:   "#b9bcc2"
    readonly property color colorBlanco: "#ffffff"
    readonly property color colorRojo:   "#ff5b52"
    readonly property color colorAmbar:  "#ffd21e"
    readonly property color colorVerde:  "#5ddc7a"

    readonly property color colorPunto: {
        if (raiz.estado === "listo") return raiz.colorVerde
        if (raiz.estado === "transcribiendo") return raiz.colorAmbar
        return raiz.colorRojo          // escuchando y error comparten el rojo; el texto los distingue
    }

    // --- Texto partido ------------------------------------------------------
    // La última palabra se pinta aparte porque es la que menos cambia entre pasadas. Separarla
    // del resto es lo que da la lectura de "esto ya está fijado, lo de delante todavía baila".
    readonly property int corte: raiz.texto.lastIndexOf(" ")
    readonly property string cuerpo: raiz.corte < 0 ? "" : raiz.texto.substring(0, raiz.corte)
    readonly property string ultima: raiz.corte < 0 ? raiz.texto : raiz.texto.substring(raiz.corte + 1)

    // El texto entra en un Text con textFormat StyledText, así que hay que escaparlo. Una
    // transcripción con un "<" suelto se comería el resto de la línea.
    function escapar(s) {
        return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }

    readonly property string textoRico: {
        if (raiz.estado === "transcribiendo") {
            if (raiz.texto.length === 0) return ""
            var c = raiz.escapar(raiz.cuerpo)
            var u = raiz.escapar(raiz.ultima)
            return (c.length > 0 ? c + " " : "")
                 + "<font color=\"" + raiz.colorBlanco + "\">" + u + "</font>"
        }
        if (raiz.texto.length > 0) return raiz.escapar(raiz.texto)
        if (raiz.estado === "escuchando") return "<font color=\"#7c828c\">Escuchando…</font>"
        return ""
    }

    // --- Medidas ------------------------------------------------------------
    // Ancho fijo. Una pastilla que crece con cada hipótesis da un salto cada dos segundos, y
    // el ancho de una superficie layer-shell no se anima bien. Fijo se lee más tranquilo y
    // esta constante es lo único que hay que tocar para ensancharla o estrecharla.
    readonly property int ancho: 760
    readonly property int alto: 52

    // --- Parar desde la propia capa -----------------------------------------
    Process { id: pararProceso }

    PanelWindow {
        id: panel

        anchors { bottom: true }
        margins { bottom: 96 }
        implicitWidth: raiz.ancho
        implicitHeight: raiz.alto

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "dictado-vivo"

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: pararProceso.exec([Quickshell.shellDir + "/dictado-vivo.sh", "parar"])
        }

        // La opacidad iría aquí, en el Item, no en el PanelWindow. QWindow::opacity no está
        // implementado en Wayland y la de un QQuickItem sí. Ahora vale 1.0 porque el alfa lo
        // lleva el color de la pastilla, pero el contenedor se deja porque es el sitio por
        // donde habría que tocar si algún día se quiere atenuar el conjunto.
        Item {
            id: velo
            anchors.fill: parent
            opacity: 1.0

            Rectangle {
                id: pastilla
                anchors.fill: parent
                radius: 14
                color: raiz.colorFondo
                border.width: 1
                border.color: "#26ffffff"

                Row {
                    id: fila
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    anchors.topMargin: 9
                    height: 26
                    spacing: 12

                    // Punto de estado. Late solo mientras se escucha, que es cuando hay algo
                    // que esperar; en los demás estados se queda fijo.
                    Rectangle {
                        id: punto
                        width: 11
                        height: 11
                        radius: 5.5
                        anchors.verticalCenter: parent.verticalCenter
                        color: raiz.colorPunto
                        Behavior on color { ColorAnimation { duration: 150 } }

                        SequentialAnimation on opacity {
                            running: raiz.estado === "escuchando"
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.22; duration: 520; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.00; duration: 520; easing.type: Easing.InOutSine }
                            onStopped: punto.opacity = 1.0
                        }
                    }

                    // La zona del texto recorta. El Text no lleva anclaje, su x se calcula.
                    // Si el texto cabe, se pega a la izquierda, detrás del punto, que es donde
                    // empieza a leerse. Si no cabe, se pega a la derecha y lo que se recorta es
                    // el principio, así que en pantalla queda lo último dicho, que es lo que se
                    // está leyendo. Con anclaje fijo a la derecha, un texto corto aparecía
                    // flotando en el extremo opuesto al punto.
                    Item {
                        id: zonaTexto
                        clip: true
                        width: fila.width - punto.width - fila.spacing
                        height: fila.height

                        Text {
                            id: textoVivo
                            x: width > zonaTexto.width ? zonaTexto.width - width : 0
                            y: (zonaTexto.height - height) / 2
                            textFormat: Text.StyledText
                            text: raiz.textoRico
                            color: raiz.estado === "error" ? raiz.colorRojo : raiz.colorGris
                            font.pixelSize: 19
                            wrapMode: Text.NoWrap
                        }
                    }
                }

                // Barra de nivel. Sigue la voz, no la certeza, es "esto está captando".
                Rectangle {
                    id: canal
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    anchors.bottomMargin: 10
                    height: 3
                    radius: 1.5
                    color: "#22ffffff"

                    Rectangle {
                        width: parent.width * raiz.nivel
                        height: parent.height
                        radius: parent.radius
                        color: raiz.colorAmbar
                        Behavior on width { NumberAnimation { duration: 70 } }
                    }
                }
            }
        }
    }
}
