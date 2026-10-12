// Diagnostico del coste del medidor, para el bloque --cpu de dictado-nivel-medir.sh.
//
// Lleva un solo PwNodePeakMonitor sobre el microfono y no registra cada emision. Los picos se
// cuentan en una propiedad y el total sale cada 5 s. El banco principal escribe una linea por
// emision en su registro, y ese registro forma parte del coste que mide, asi que para medir el
// coste hace falta esta version callada, que es la que se parece a lo que correria en produccion.
//
// El patron del micro llega por entorno, igual que en el banco principal.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Scope {
    id: raiz
    property int n: 0

    // OJO con Quickshell.env. Su segundo argumento NO es un valor por defecto, devuelve null si
    // la variable no esta puesta. Medido el 2026-10-11, y por eso el respaldo va con `||`.
    readonly property string patronMicro: Quickshell.env("DICTADO_FUENTE") || "Wireless_Mic_Rx"

    function buscar(patron) {
        if (!patron) return null
        const v = Pipewire.nodes.values
        for (let i = 0; i < v.length; i++) {
            const x = v[i]
            if (x.name && x.name.indexOf(patron) !== -1) return x
        }
        return null
    }

    PwNodePeakMonitor {
        node: raiz.buscar(raiz.patronMicro)
        onPeakChanged: raiz.n = raiz.n + 1
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: console.log("CUENTA " + raiz.n)
    }
}
