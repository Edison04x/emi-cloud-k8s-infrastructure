#!/bin/bash

# ==============================================================================
# SCRIPT: auto-metallb.sh (Self-Healing Network Daemon)
# DESCRIPCION: Demonio de Alta Disponibilidad (HA) para auto-escalado dinámico
#              del pool de IPs de MetalLB. Incluye prevención de 'split-brain'
#              mediante validación de estado (Leader Election con Keepalived).
# AUTORES: Edison, Izan, Marc (EMI Cloud)
# ==============================================================================

POOL_NAME="ip-pool"
NAMESPACE="metallb-system"
ARCHIVO_LOG="/home/asix/k8s-configyaml-scripts/metallb-auto.log"

# CONFIGURACION: IP Virtual (VIP) asignada por el balanceador Keepalived
IP_VIRTUAL="<VIP_KEEPALIVED>"

# Bucle de monitorizacion continua (Daemon mode)
while true; do

    # LEADER ELECTION (Filtro de Estado):
    # Comprueba si este nodo de Control Plane posee actualmente la VIP.
    # Esto evita ejecuciones concurrentes y colisiones en un entorno Multi-Master.
    SOY_EL_LIDER=$(ip addr | grep -c "$IP_VIRTUAL")

    if [ "$SOY_EL_LIDER" -gt 0 ]; then

        # Sondeo de servicios LoadBalancer huerfanos (sin IP asignada)
        PENDIENTES=$(kubectl get svc -A | grep LoadBalancer | grep -c "<pending>")

        if [ "$PENDIENTES" -gt 0 ]; then
            FECHA=$(date '+%Y-%m-%d %H:%M:%S')
            
            # Extraccion del estado actual desde la API de Kubernetes
            RANGO_ACTUAL=$(kubectl get ipaddresspool $POOL_NAME -n $NAMESPACE -o jsonpath='{.spec.addresses[0]}')
            
            # Parsing del bloque CIDR / Rango de IPs
            IP_INICIO=$(echo $RANGO_ACTUAL | cut -d'-' -f1)
            IP_FIN=$(echo $RANGO_ACTUAL | cut -d'-' -f2)
            
            BASE_IP=$(echo $IP_FIN | cut -d'.' -f1-3)
            ULTIMO_OCTETO=$(echo $IP_FIN | cut -d'.' -f4)
            
            # Calculo de expansion elastica (Incremento dinamico de 50 IPs)
            NUEVO_OCTETO=$((ULTIMO_OCTETO + 50))
            
            # Control de desbordamiento de subred (Limite estricto para IPv4 /24)
            if [ "$NUEVO_OCTETO" -gt 254 ]; then
                NUEVO_OCTETO=254
            fi
            
            NUEVA_IP_FIN="${BASE_IP}.${NUEVO_OCTETO}"
            NUEVO_RANGO="${IP_INICIO}-${NUEVA_IP_FIN}"
            
            if [ "$ULTIMO_OCTETO" -eq 254 ]; then
                echo "[$FECHA] [CRITICAL] Limite maximo de la subred alcanzado (.254). Intervencion manual requerida." >> "$ARCHIVO_LOG"
                exit 1
            fi

            # Aplicacion de la mutacion en caliente via API (Patching)
            echo "[$FECHA] [WARN] [LEADER-ACTIVE] Pool agotado. Ejecutando expansion dinamica a $NUEVO_RANGO..." >> "$ARCHIVO_LOG"
            kubectl patch ipaddresspool $POOL_NAME -n $NAMESPACE --type='merge' -p "{\"spec\":{\"addresses\":[\"$NUEVO_RANGO\"]}}" >> "$ARCHIVO_LOG" 2>&1

            if [ $? -eq 0 ]; then
                echo "[$FECHA] [SUCCESS] Infraestructura auto-escalada correctamente a $NUEVO_RANGO." >> "$ARCHIVO_LOG"
            else
                echo "[$FECHA] [ERROR] Fallo critico al intentar parchear la API de Kubernetes." >> "$ARCHIVO_LOG"
            fi
        fi
    fi

    # Intervalo de sondeo (Polling rate de 10 segundos)
    sleep 10
done