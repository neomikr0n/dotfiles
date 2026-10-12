// Banco de medida del medidor de nivel. No dibuja nada, porque es un Scope y no una ventana.
//
// Registra tres cosas con marca de tiempo, una linea por suceso, para que el analisis pueda
// alinearlas despues.
//   P    cada emision de peakChanged del sumidero de medida
//   PM   cada emision de peakChanged del microfono real
//   H    una muestra cada 100 ms del valor del sumidero
//
// Los canales solo se llenan si el formato que negocia PipeWire acaba en F32. Si el nodo entrega
// otra cosa, Quickshell descarta el formato, deja los picos vacios y avisa en su registro.
//
// El nombre del sumidero y el patron del micro llegan por entorno, para que el guion que lanza
// esto sea el unico sitio donde estan escritos.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Scope {
    id: raiz

    // OJO con Quickshell.env. Su segundo argumento NO es un valor por defecto, devuelve null si
    // la variable no esta puesta. Medido el 2026-10-11, y por eso el respaldo va con `||`.
    readonly property string sumidero: Quickshell.env("DICTADO_NIVEL_SUMIDERO") || "dictado-nivel-rig"
    readonly property string patronMicro: Quickshell.env("DICTADO_FUENTE") || "Wireless_Mic_Rx"

    // SDL y PipeWire no nombran igual el mismo dispositivo. Aqui se busca por el nombre de
    // PipeWire, que es el mismo que ve pactl. Sin patron no se busca nada, porque indexOf("")
    // casa con el primer nodo de la lista y el monitor acabaria colgado de un nodo cualquiera.
    function buscar(patron) {
        if (!patron) return null
        const v = Pipewire.nodes.values
        for (let i = 0; i < v.length; i++) {
            const n = v[i]
            if (n.name && n.name.indexOf(patron) !== -1) return n
        }
        return null
    }

    readonly property var nodoSumidero: buscar(sumidero)
    readonly property var nodoMicro: buscar(patronMicro)

    PwNodePeakMonitor {
        id: monSumidero
        node: raiz.nodoSumidero
        onPeakChanged: console.log("P " + Date.now() + " " + peak)
        onChannelsChanged: console.log("CANALES-SUM " + JSON.stringify(channels))
    }

    PwNodePeakMonitor {
        id: monMicro
        node: raiz.nodoMicro
        onPeakChanged: console.log("PM " + Date.now() + " " + peak)
        onChannelsChanged: console.log("CANALES-MIC " + JSON.stringify(channels))
    }

    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: console.log("H " + Date.now() + " " + monSumidero.peak)
    }

    // Red de seguridad. El guion lo mata al terminar, esto es por si algo se queda colgado.
    Timer { interval: 120000; running: true; onTriggered: Qt.quit() }
}
