// shell.qml — Aviso de «siguiente ronda» para el bucle de KTimer.
//
// Superficie layer-shell propia: arriba a la izquierda, tarjeta negra con el
// texto y el borde en naranja, entrando deslizandose desde arriba.
//
// Se dispara por IPC desde el script:
//     qs -p ~/.config/ktimer-alert ipc call ktimer-alert mostrar
//
// OJO con el nombre de las funciones: `qs ipc` tiene los subcomandos show /
// call / wait / listen / prop, y un argumento que se llame `show` NO se ejecuta:
// el parser lo toma por el subcomando e imprime el listado del target,
// devolviendo exit 0. Por eso aqui son mostrar / ocultar / estado. (Medido
// 2026-10-02: `... call ktimer-alert show` listaba las funciones; `hide` y
// `status` si se ejecutaban.)
//
// NO es una notificacion del sistema: DMS no pinta este aviso. La notificacion
// real la sigue mandando el script con notify-send (para conservar el historial
// y el respeto de «No molestar»), y una regla de DMS silencia su popup para que
// no salga por duplicado. Ver share/scripts/ktimer-next-round.sh.
//
// Se lanza con:  qs -p ~/.config/ktimer-alert
// (o por el servicio de usuario ktimer-alert.service)
//
// ── Sobre la animacion ───────────────────────────────────────────────────────
// La superficie NO puede nacer oculta. Un PanelWindow con visible:false no
// mapea superficie, y sin superficie no hay donde animar: la tarjeta aparece ya
// colocada. Por eso la superficie esta SIEMPRE mapeada, es transparente y tiene
// alto de sobra; la tarjeta arranca por encima del recorte (y negativa) y baja.
// El recorte lo hace la propia superficie: lo que sobresale no se dibuja.
//
// El mask vacio evita que la superficie capture el raton: aunque este siempre
// mapeada, los clicks de la esquina pasan de largo.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: raiz

    readonly property int ancho: 340
    readonly property int alto: 58
    readonly property int margenSup: 16
    // La barra de DMS es vertical, ocupa los primeros 44 px y esta SIEMPRE
    // visible (autoHide solo la esconde con ventanas maximizadas). DMS ancla su
    // popup «Top Left» a Theme.popupDistance (=4) porque getAdjacentBarInfo
    // descarta las barras con autoHide:true y deja leftBar=0, asi que su popup
    // se pisa con la barra. Aqui no se copia ese defecto: 44 + 4 de aire.
    readonly property int margenIzq: 48
    readonly property int msEntrada: 400
    readonly property int msSalida: 300
    readonly property int msVisible: 4000

    // Estado real del aviso. Independiente de la visibilidad de la superficie.
    property bool mostrando: false

    PanelWindow {
        id: ventana

        // Misma maquinaria que usa DMS para su tooltip y su popup de
        // notificaciones: capa overlay, sin reservar sitio en el borde.
        WlrLayershell.namespace: "ktimer-alert"
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        color: "transparent"
        anchors {
            top: true
            left: true
        }
        margins {
            // top 0: la superficie arranca en el borde de la pantalla, para que
            // la tarjeta pueda empezar fuera y entrar deslizando.
            top: 0
            left: raiz.margenIzq
        }
        implicitWidth: raiz.ancho
        // Alto de sobra para alojar la tarjeta en su posicion final.
        implicitHeight: raiz.alto + raiz.margenSup

        // SIEMPRE mapeada. Ver la nota de arriba.
        visible: true

        // Region vacia: la superficie no captura el raton. El aviso no puede
        // bloquear un click en la esquina mientras esta en pantalla.
        mask: Region {}

        Rectangle {
            id: tarjeta
            width: parent.width
            height: raiz.alto
            radius: 12
            color: "#000000"
            border.width: 1
            border.color: "#FF7A00"
            // Fuera del recorte de la superficie cuando esta oculto.
            y: raiz.mostrando ? raiz.margenSup : -(raiz.alto + 2)

            Behavior on y {
                NumberAnimation {
                    duration: raiz.mostrando ? raiz.msEntrada : raiz.msSalida
                    easing.type: raiz.mostrando ? Easing.OutCubic : Easing.InCubic
                }
            }

            Text {
                anchors.centerIn: parent
                text: "🦖🦕 Next round is up...!"
                color: "#FF7A00"
                font.pixelSize: 15
                font.weight: Font.Medium
            }
        }

        Timer {
            id: cierre
            interval: raiz.msVisible
            onTriggered: raiz.mostrando = false
        }

        IpcHandler {
            target: "ktimer-alert"

            function mostrar(): string {
                raiz.mostrando = true;
                cierre.restart();
                return "KTIMER_ALERT_SHOW_OK";
            }

            function ocultar(): string {
                cierre.stop();
                raiz.mostrando = false;
                return "KTIMER_ALERT_HIDE_OK";
            }

            function estado(): string {
                return raiz.mostrando ? "mostrando" : "oculto";
            }
        }
    }
}
