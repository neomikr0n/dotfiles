/* dji-bateria. Lee la batería de los transmisores de un receptor DJI Mic por USB en Linux.
 *
 * QUÉ HACE Y QUÉ NO
 * El receptor DJI (VID 2ca3, PID 4011) publica el estado en la interfaz USB 6 (clase ff, sin
 * driver en el kernel) por el endpoint bulk IN 0x86. NO hay comando para pedir la batería:
 * el receptor la EMPUJA, ~10 veces por segundo. Este programa se limita a abrir esa interfaz,
 * leer el flujo y sacar de cada trama lo que se sabe decodificar.
 *
 * NO envía nada al receptor. No toca la interfaz de audio (interfaz 1), así que no interfiere
 * con la grabación.
 *
 * LA BATERÍA SON 7 ESCALONES, NO UN PORCENTAJE
 * El campo es un medidor de 3 bits donde MÁS ALTO = MÁS DESCARGADO:
 *     1 = llena, 6 = aviso de batería baja, 7 = lectura terminal antes de apagarse
 * El 0 no se ha observado nunca. Por eso este programa imprime el escalón, que es el dato real,
 * y NO un porcentaje. Si alguien te enseña un "47 %" de estos micrófonos, se lo ha inventado.
 *
 * SOLO EN PROTOCOLO v2
 * El latido del protocolo v1 no lleva campo de batería. Si el receptor habla v1, este programa
 * lo dice en vez de inventarse un número. La versión se detecta por el byte 11.
 *
 * USO
 *     dji-bateria                 estado en texto, una vez
 *     dji-bateria --json          lo mismo en JSON, para un widget
 *     dji-bateria --vigilar       se queda leyendo y avisa cuando baja de escalón
 *     dji-bateria --autotest      verifica el CRC y el decodificador contra tramas conocidas
 *     dji-bateria --crudo         vuelca las tramas en hexadecimal (diagnóstico)
 *     dji-bateria --esperar N     segundos máximos esperando un empujón de estado (por defecto 3)
 *
 * Compilar:  gcc -O2 -o dji-bateria dji-bateria.c $(pkg-config --cflags --libs libusb-1.0)
 *
 * Protocolo: ShadowBitBasher/DJI-Mic-Control (PROTOCOL.md, dominio público).
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <signal.h>
#include <time.h>
#include <errno.h>
#include <libusb-1.0/libusb.h>

#define VID 0x2ca3
#define PID 0x4011
#define IFACE_BATERIA 6
#define EP_IN 0x86

/* ---------------------------------------------------------------- CRC */

/* CRC-8 del encabezado. Parámetros forzados por fuerza bruta contra las seis longitudes de trama
 * documentadas (14->0x66, 19->0x03, 22->0xfc, 56->0xe1, 70->0x8b, 84->0xf6) y sale UNA sola
 * combinación: polinomio 0x31, inicio 0xEE, con el byte de entrada y el resultado reflejados.
 * Ojo: NO es "polinomio reflejado + algoritmo reflejado", eso refleja dos veces y no cuadra. */
static uint8_t rev8(uint8_t x)
{
    uint8_t r = 0;
    for (int i = 0; i < 8; i++) { r = (uint8_t)((r << 1) | (x & 1)); x >>= 1; }
    return r;
}

static uint8_t crc8_encabezado(const uint8_t *d)
{
    uint8_t c = 0xEE;
    for (int k = 0; k < 3; k++) {
        c ^= rev8(d[k]);
        for (int i = 0; i < 8; i++)
            c = (c & 0x80) ? (uint8_t)((c << 1) ^ 0x31) : (uint8_t)(c << 1);
    }
    return rev8(c);
}

/* CRC-16/IBM-SDLC reflejado. El CRC se elige para que sumar la trama ENTERA caiga en un residuo
 * fijo: 0xbb01 con semilla 0x0000 (v1) y 0x0000 con semilla 0x3692 (v2). Validado contra las dos
 * tramas de comando documentadas. */
static uint16_t crc16(const uint8_t *d, size_t n, uint16_t semilla)
{
    uint16_t c = semilla;
    for (size_t k = 0; k < n; k++) {
        c ^= d[k];
        for (int i = 0; i < 8; i++)
            c = (c & 1) ? (uint16_t)((c >> 1) ^ 0x8408) : (uint16_t)(c >> 1);
    }
    return c;
}

static int crc16_valido(const uint8_t *f, size_t n, int version)
{
    if (n < 4) return 0;
    uint16_t r = crc16(f, n, version == 1 ? 0x0000 : 0x3692);
    return version == 1 ? (r == 0xbb01) : (r == 0x0000);
}

/* ---------------------------------------------------------------- estado */

#define MAX_TX 2

typedef struct {
    int  valido;              /* hay datos de esta unidad */
    int  unidad;              /* 1 = TX1, 2 = TX2 (numeración FÍSICA, la que reporta el receptor) */
    int  nivel;               /* 1..7, más alto = más descargado. 0 = desconocido */
    int  cargando;            /* 0/1 */
    char serial[24];
    char nombre[48];
} tx_t;

typedef struct {
    int    version;           /* 0 = aún no se sabe, 1, 2 */
    int    conectados;        /* bitmask: 1 = TX1, 2 = TX2 */
    int    tramas;            /* tramas reconocidas */
    int    descartadas;       /* tramas con CRC malo */
    tx_t   tx[MAX_TX];
    char   rx_serial[24];
} estado_t;

static tx_t *ranura(estado_t *e, int unidad)
{
    if (unidad < 1 || unidad > MAX_TX) return NULL;
    tx_t *t = &e->tx[unidad - 1];
    t->unidad = unidad;
    return t;
}

/* ---------------------------------------------------------------- decodificación */

/* Nivel de batería: byte de flags en la ranura +7, bits 0x1c, leído como (b >> 2) & 0x07.
 * El bit 0x02 del mismo byte es "en la base / cargando", y es independiente del nivel:
 * los dos pueden estar puestos a la vez. */
static void decodificar_estado_v2(const uint8_t *f, size_t n, estado_t *e)
{
    int ranuras = (int)((n - 54) / 32);   /* 0, 1 o 2 */
    e->conectados = f[44] & 0x03;

    for (int i = 0; i < ranuras && i < MAX_TX; i++) {
        const uint8_t *s = f + 52 + 32 * i;
        int unidad = s[1];                 /* numeración física, no la posición */
        if (unidad < 1 || unidad > MAX_TX) continue;
        uint8_t flags = s[7];
        tx_t *t = ranura(e, unidad);
        if (!t) continue;
        t->valido   = 1;
        t->nivel    = (flags >> 2) & 0x07;
        t->cargando = (flags & 0x02) ? 1 : 0;
    }
}

/* Empujones de identidad: a partir del byte 14, registros [etiqueta][unidad][3 reservados][largo][datos].
 * Etiqueta 0x01 -> 4 bytes de versión de firmware (en orden inverso) + 14 bytes de serie ASCII.
 * Etiqueta 0x06 -> nombre de producto en ASCII. Unidad 0 = receptor, 1/2 = ranura de TX (base 0). */
static void decodificar_identidad_v2(const uint8_t *f, size_t n, estado_t *e)
{
    size_t i = 14;
    while (i + 6 <= n - 2) {
        uint8_t tag = f[i], unidad = f[i + 1], largo = f[i + 5];
        if (i + 6 + largo > n - 2) break;
        const uint8_t *d = f + i + 6;

        if (tag == 0x01 && largo >= 18) {
            char serial[16];
            memcpy(serial, d + 4, 14);
            serial[14] = '\0';
            if (unidad == 0) {
                snprintf(e->rx_serial, sizeof e->rx_serial, "%s", serial);
            } else if (unidad <= MAX_TX) {
                tx_t *t = ranura(e, unidad);
                if (t) { t->valido = 1; snprintf(t->serial, sizeof t->serial, "%s", serial); }
            }
        } else if (tag == 0x06 && unidad >= 1 && unidad <= MAX_TX) {
            tx_t *t = ranura(e, unidad);
            if (t) {
                size_t k = largo < sizeof t->nombre - 1 ? largo : sizeof t->nombre - 1;
                memcpy(t->nombre, d, k);
                t->nombre[k] = '\0';
                t->valido = 1;
            }
        }
        i += 6 + largo;
    }
}

/* Devuelve 1 si reconoció la trama. */
static int decodificar(const uint8_t *f, size_t n, estado_t *e, int *crc_ok)
{
    if (n < 14 || f[0] != 0x55 || f[2] != 0x04) return 0;

    /* El byte 11 es la única marca fiable de versión, con 0x00 para v1 y 0x03 para v2. */
    if (f[9] != 0x5b || f[10] != 0x03) {
        /* No es un empujón de estado, sino un ACK, un comando o algo que no esperamos. */
        return 0;
    }
    int version = (f[11] == 0x03) ? 2 : 1;
    e->version = version;

    if (crc_ok) *crc_ok = crc16_valido(f, n, version);
    e->tramas++;

    if (version == 1) {
        /* El latido v1 no publica batería. Se reconoce la trama para poder decir por qué no hay
         * dato, que es más útil que un silencio. */
        return 1;
    }

    switch (n) {
    case 54: case 86: case 118:
        decodificar_estado_v2(f, n, e);
        return 1;
    case 70: case 124: case 178:
        decodificar_identidad_v2(f, n, e);
        return 1;
    case 30:
        return 1;   /* empujón de nivel de audio: no interesa aquí */
    default:
        return 1;
    }
}

/* ---------------------------------------------------------------- presentación */

static const char *etiqueta_nivel(int nivel)
{
    switch (nivel) {
    case 1: return "llena";
    case 2: return "alta";
    case 3: return "media-alta";
    case 4: return "media";
    case 5: return "media-baja";
    case 6: return "BAJA";
    case 7: return "CRÍTICA";
    default: return "desconocida";
    }
}

static void imprimir_texto(const estado_t *e)
{
    if (e->version == 1) {
        printf("El receptor habla protocolo v1.\n");
        printf("El protocolo v1 NO publica la batería de los transmisores: solo estado, nivel de\n");
        printf("audio, firmware y número de serie. Para tener batería hay que actualizar el\n");
        printf("firmware del receptor (aplicación de DJI) a una versión que hable v2.\n");
        if (e->rx_serial[0]) printf("Receptor: %s\n", e->rx_serial);
        return;
    }
    if (e->version == 0) {
        printf("No llegó ninguna trama de estado. ¿Está el receptor conectado y encendido?\n");
        return;
    }

    int alguno = 0;
    for (int i = 0; i < MAX_TX; i++) {
        const tx_t *t = &e->tx[i];
        if (!t->valido) continue;
        alguno = 1;
        printf("TX%d", t->unidad);
        if (t->nombre[0]) printf(" (%s)", t->nombre);
        if (t->nivel) {
            printf(": escalón %d/7 — %s", t->nivel, etiqueta_nivel(t->nivel));
            if (t->cargando) printf(" [cargando]");
        } else {
            printf(": sin dato de batería todavía");
        }
        if (t->serial[0]) printf("  serie %s", t->serial);
        printf("\n");
    }
    if (!alguno) {
        printf("El receptor responde (v2) pero ningún transmisor está emparejado o encendido.\n");
    }
    if (e->rx_serial[0]) printf("Receptor: %s\n", e->rx_serial);
}

static void imprimir_json(const estado_t *e)
{
    printf("{");
    printf("\"version\":%d,", e->version);
    printf("\"conectados\":%d,", e->conectados);
    printf("\"receptor\":\"%s\",", e->rx_serial);
    printf("\"tx\":[");
    int primero = 1;
    for (int i = 0; i < MAX_TX; i++) {
        const tx_t *t = &e->tx[i];
        if (!t->valido) continue;
        if (!primero) printf(",");
        primero = 0;
        printf("{\"unidad\":%d,\"nombre\":\"%s\",\"escalon\":%d,\"etiqueta\":\"%s\","
               "\"cargando\":%s,\"serie\":\"%s\"}",
               t->unidad, t->nombre, t->nivel, etiqueta_nivel(t->nivel),
               t->cargando ? "true" : "false", t->serial);
    }
    printf("]}");
    printf("\n");
}

static void imprimir_simple(const estado_t *e)
{
    /* Una línea, sin JSON ni adornos, para que un script de shell la lea con un read.
     * Formato:  version=<n> tx1=<escalon>:<cargando> tx2=<escalon>:<cargando>
     * Los escalones van de 1 (llena) a 7 (crítica). 0 = sin dato. */
    printf("version=%d", e->version);
    for (int u = 1; u <= MAX_TX; u++) {
        const tx_t *t = &e->tx[u - 1];
        printf(" tx%d=%d:%d", u, t->valido ? t->nivel : 0, t->valido ? t->cargando : 0);
    }
    printf("\n");
}

/* ---------------------------------------------------------------- USB */

static libusb_device_handle *abrir(libusb_context *ctx)
{
    libusb_device_handle *h = libusb_open_device_with_vid_pid(ctx, VID, PID);
    if (!h) return NULL;
    if (libusb_kernel_driver_active(h, IFACE_BATERIA) == 1) {
        libusb_detach_kernel_driver(h, IFACE_BATERIA);
    }
    if (libusb_claim_interface(h, IFACE_BATERIA) != 0) {
        libusb_close(h);
        return NULL;
    }
    return h;
}

/* ---------------------------------------------------------------- autotest */

static int autotest(void)
{
    int fallos = 0;

    /* 1) CRC-8 del encabezado contra las seis longitudes documentadas. */
    struct { uint8_t largo, esperado; } l8[] = {
        {0x0e, 0x66}, {0x13, 0x03}, {0x16, 0xfc},
        {0x38, 0xe1}, {0x46, 0x8b}, {0x54, 0xf6},
    };
    for (size_t i = 0; i < sizeof l8 / sizeof *l8; i++) {
        uint8_t d[3] = {0x55, l8[i].largo, 0x04};
        uint8_t got = crc8_encabezado(d);
        int ok = (got == l8[i].esperado);
        if (!ok) fallos++;
        printf("  %-4s CRC-8  trama de %3u bytes -> 0x%02x (esperado 0x%02x)\n",
               ok ? "OK" : "FALLA", l8[i].largo, got, l8[i].esperado);
    }

    /* 2) CRC-16 como VALIDADOR de residuo, contra las dos tramas de comando documentadas. */
    {
        uint8_t v1[] = {0x55,0x13,0x04,0x03,0x02,0x5a,0x01,0x00,0x40,0x5b,
                        0x01,0x00,0x03,0x1d,0x00,0x01,0x01,0x91,0xfb};
        uint8_t v2[] = {0x55,0x16,0x04,0xfc,0x02,0x5a,0x40,0xb6,0x40,0x5b,0x01,
                        0x02,0xff,0xff,0x00,0x00,0x37,0x00,0x01,0x00,0xdd,0xe2};
        int a = crc16_valido(v1, sizeof v1, 1);
        int b = crc16_valido(v2, sizeof v2, 2);
        if (!a) fallos++;
        if (!b) fallos++;
        printf("  %-4s CRC-16 residuo 0xbb01 en la trama v1\n", a ? "OK" : "FALLA");
        printf("  %-4s CRC-16 residuo 0x0000 en la trama v2\n", b ? "OK" : "FALLA");
    }

    /* 3) CRC-16 como GENERADOR en v2 (donde el residuo es 0, así que el CRC calculado sobre el
     *    cuerpo es el que va en la trama, little-endian). */
    {
        uint8_t v2[] = {0x55,0x16,0x04,0xfc,0x02,0x5a,0x40,0xb6,0x40,0x5b,0x01,
                        0x02,0xff,0xff,0x00,0x00,0x37,0x00,0x01,0x00};
        uint16_t c = crc16(v2, sizeof v2, 0x3692);
        int ok = (c == 0xe2dd);
        if (!ok) fallos++;
        printf("  %-4s CRC-16 generado 0x%04x (la trama lleva 0xe2dd)\n", ok ? "OK" : "FALLA", c);
    }

    /* 4) Decodificador: trama v2 de estado con dos transmisores, fabricada a mano con niveles
     *    distintos y uno cargando, para comprobar que se leen del sitio correcto. */
    {
        uint8_t f[118];
        memset(f, 0, sizeof f);
        f[0] = 0x55; f[1] = 118; f[2] = 0x04; f[3] = crc8_encabezado(f);
        f[4] = 0x5a; f[5] = 0x02; f[9] = 0x5b; f[10] = 0x03; f[11] = 0x03;
        f[12] = 0x66; f[44] = 0x03;
        /* ranura 0: unidad física 1, nivel 3, sin cargar */
        f[52 + 1] = 0x01; f[52 + 7] = (uint8_t)((3 << 2) | 0x20);
        /* ranura 1: unidad física 2, nivel 7, cargando */
        f[84 + 1] = 0x02; f[84 + 7] = (uint8_t)((7 << 2) | 0x02 | 0x20);
        uint16_t c = crc16(f, 116, 0x3692);
        f[116] = (uint8_t)(c & 0xFF); f[117] = (uint8_t)(c >> 8);

        estado_t e; memset(&e, 0, sizeof e);
        int crc_ok = 0;
        decodificar(f, sizeof f, &e, &crc_ok);
        int ok = crc_ok && e.tx[0].valido && e.tx[0].unidad == 1 && e.tx[0].nivel == 3 &&
                 !e.tx[0].cargando && e.tx[1].valido && e.tx[1].unidad == 2 &&
                 e.tx[1].nivel == 7 && e.tx[1].cargando;
        if (!ok) fallos++;
        printf("  %-4s decodificador: TX1 nivel %d cargando %d | TX2 nivel %d cargando %d | CRC %s\n",
               ok ? "OK" : "FALLA",
               e.tx[0].nivel, e.tx[0].cargando, e.tx[1].nivel, e.tx[1].cargando,
               crc_ok ? "bien" : "mal");
    }

    printf("\n%s\n", fallos ? "HAY FALLOS" : "todo correcto");
    return fallos ? 1 : 0;
}

/* ---------------------------------------------------------------- principal */

static volatile sig_atomic_t parar = 0;
static void al_parar(int s) { (void)s; parar = 1; }

int main(int argc, char **argv)
{
    int json = 0, crudo = 0, vigilar = 0, simple = 0, esperar = 3;

    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--json")) json = 1;
        else if (!strcmp(argv[i], "--simple")) simple = 1;
        else if (!strcmp(argv[i], "--crudo")) crudo = 1;
        else if (!strcmp(argv[i], "--vigilar")) vigilar = 1;
        else if (!strcmp(argv[i], "--autotest")) return autotest();
        else if (!strcmp(argv[i], "--esperar") && i + 1 < argc) esperar = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--ayuda") || !strcmp(argv[i], "-h")) {
            printf("uso: %s [--json] [--simple] [--crudo] [--vigilar] [--esperar SEGUNDOS] [--autotest]\n", argv[0]);
            return 0;
        } else {
            fprintf(stderr, "opción no reconocida: %s\n", argv[i]);
            return 2;
        }
    }

    libusb_context *ctx = NULL;
    if (libusb_init(&ctx) != 0) { fprintf(stderr, "no pude inicializar libusb\n"); return 1; }

    libusb_device_handle *h = abrir(ctx);
    if (!h) {
        /* Distinguir "no está" de "no me dejan" importa, porque la solución es distinta. */
        libusb_device **lista = NULL;
        ssize_t n = libusb_get_device_list(ctx, &lista);
        int presente = 0;
        for (ssize_t i = 0; i < n; i++) {
            struct libusb_device_descriptor dd;
            if (libusb_get_device_descriptor(lista[i], &dd) != 0) continue;
            if (dd.idVendor == VID && dd.idProduct == PID) { presente = 1; break; }
        }
        if (lista) libusb_free_device_list(lista, 1);

        if (presente) {
            fprintf(stderr,
                "El receptor DJI está conectado pero no tengo permiso para hablar con él.\n\n"
                "Falta una regla de udev. Créala con:\n\n"
                "  sudo tee /etc/udev/rules.d/60-dji-mic.rules >/dev/null <<'EOF'\n"
                "  SUBSYSTEM==\"usb\", ATTR{idVendor}==\"2ca3\", ATTR{idProduct}==\"4011\", MODE=\"0660\", GROUP=\"input\"\n"
                "  EOF\n"
                "  sudo udevadm control --reload-rules && sudo udevadm trigger\n\n"
                "Luego DESENCHUFA y vuelve a enchufar el receptor (la regla no se aplica sola a lo\n"
                "que ya está conectado). Después, si no estás en el grupo input: sudo usermod -aG input $USER\n");
            libusb_exit(ctx);
            return 3;
        }
        fprintf(stderr, "No encuentro el receptor DJI (VID %04x PID %04x). ¿Está enchufado?\n", VID, PID);
        libusb_exit(ctx);
        return 1;
    }

    signal(SIGINT, al_parar);
    signal(SIGTERM, al_parar);

    estado_t e;
    memset(&e, 0, sizeof e);
    uint8_t buf[4096];
    size_t acumulado = 0;
    time_t limite = time(NULL) + esperar;
    int crudo_restante = crudo ? 12 : 0;
    int ultimo_nivel[MAX_TX + 1];
    for (int i = 0; i <= MAX_TX; i++) ultimo_nivel[i] = -1;

    while (!parar) {
        int leidos = 0;
        int r = libusb_bulk_transfer(h, EP_IN, buf + acumulado,
                                     (int)(sizeof buf - acumulado), &leidos, 500);
        if (r == 0 && leidos > 0) {
            acumulado += (size_t)leidos;
        } else if (r != 0 && r != LIBUSB_ERROR_TIMEOUT) {
            fprintf(stderr, "error de lectura USB: %s\n", libusb_error_name(r));
            break;
        }

        /* Se trocean las tramas: buscar 0x55 con 0x04 en la posición +2, y tomar el largo del
         * byte 1. Nada se cree sin comprobar que la trama entera está en el búfer. */
        size_t i = 0;
        while (i + 4 <= acumulado) {
            if (buf[i] != 0x55 || buf[i + 2] != 0x04) { i++; continue; }
            size_t largo = buf[i + 1];
            if (largo < 14) { i++; continue; }
            if (i + largo > acumulado) break;   /* incompleta: esperar más datos */

            if (crudo_restante > 0) {
                printf("trama de %zu bytes:", largo);
                for (size_t k = 0; k < largo; k++) printf(" %02x", buf[i + k]);
                printf("\n");
                crudo_restante--;
            }

            int crc_ok = 0;
            estado_t antes = e;
            if (decodificar(buf + i, largo, &e, &crc_ok)) {
                if (!crc_ok) e.descartadas++;
                /* En modo vigilar, avisar cuando el escalón empeora. */
                if (vigilar) {
                    for (int u = 1; u <= MAX_TX; u++) {
                        int antes_n = antes.tx[u - 1].nivel, ahora = e.tx[u - 1].nivel;
                        if (ahora && antes_n && ahora > antes_n) {
                            printf("TX%d: escalón %d -> %d (%s)\n", u, antes_n, ahora,
                                   etiqueta_nivel(ahora));
                            fflush(stdout);
                        }
                        if (ahora && ultimo_nivel[u] < 0) ultimo_nivel[u] = ahora;
                    }
                }
            }
            i += largo;
        }
        if (i > 0) {
            memmove(buf, buf + i, acumulado - i);
            acumulado -= i;
        }
        if (acumulado >= sizeof buf) acumulado = 0;   /* búfer lleno sin trama válida: descartar */

        if (!vigilar && e.tramas > 0 && e.version == 2 && time(NULL) >= limite) break;
        if (!vigilar && e.version == 1 && e.tramas > 2) break;
        if (!vigilar && time(NULL) > limite + esperar) break;
    }

    libusb_release_interface(h, IFACE_BATERIA);
    libusb_close(h);
    libusb_exit(ctx);

    if (vigilar) return 0;
    if (json) imprimir_json(&e);
    else if (simple) imprimir_simple(&e);
    else imprimir_texto(&e);
    if (e.descartadas) fprintf(stderr, "(%d tramas con CRC incorrecto, descartadas)\n", e.descartadas);
    return 0;
}
