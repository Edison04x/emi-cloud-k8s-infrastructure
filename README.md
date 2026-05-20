# ⚡ EMI Cloud — Enterprise Kubernetes On-Premise

> **Resiliencia Tecnológica con Conciencia Sostenible**
> Infraestructura Cloud Privada de Alta Disponibilidad sobre hardware Bare-Metal, orquestada con Kubernetes y filosofía Open Source.

[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.30-326CE5?style=flat-square&logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04_LTS-E95420?style=flat-square&logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Prometheus](https://img.shields.io/badge/Prometheus-Monitoring-E6522C?style=flat-square&logo=prometheus&logoColor=white)](https://prometheus.io/)
[![Grafana](https://img.shields.io/badge/Grafana-Dashboards-F46800?style=flat-square&logo=grafana&logoColor=white)](https://grafana.com/)
[![Cloudflare](https://img.shields.io/badge/Cloudflare-Zero--Trust-F38020?style=flat-square&logo=cloudflare&logoColor=white)](https://www.cloudflare.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

---

## 👥 Autores

Este proyecto es el Trabajo Final de Grado del **Ciclo Formativo de Grado Superior en Administración de Sistemas Informáticos y Redes (ASIX)** — Curso 2025–2026.

| Autor | Perfil |
|---|---|
| **Edison Garzón Monroy** | SysAdmin / Cloud Junior |
| **Izan Jané Carvajal** | SysAdmin / Cloud Junior |
| **Marc Pellegrino Crua** | SysAdmin / Cloud Junior |

> 💡 Somos perfiles Junior recién graduados, pero este proyecto demuestra que entendemos y aplicamos arquitecturas de nivel empresarial real: Alta Disponibilidad, Self-Healing, Zero-Trust y Observabilidad proactiva. Estamos listos para aportar valor desde el primer día.

---

## 🎯 El Problema que Resolvemos

Las PYMES (e-commerces, agencias de marketing, empresas SaaS) dependen críticamente de su infraestructura digital, pero afrontan dos problemas crónicos al usar nube pública:

- 💸 **Facturas variables e impredecibles** que dificultan la planificación financiera.
- 🔒 **Pérdida de soberanía sobre sus datos**, al delegar en infraestructura de terceros.

Además, una simple caída de servidor no solo supone pérdidas económicas inmediatas, sino daños reputacionales graves y paralización total de la actividad.

## 💡 La Solución: EMI Cloud

**EMI Cloud** es un proveedor local de **Infraestructura Cloud Privada de Alta Disponibilidad (HA)** que democratiza las tecnologías de nivel enterprise para PYMES.

Nuestra propuesta se asienta sobre tres pilares:

| Pilar | Descripción |
|---|---|
| 🛡️ **Continuidad de Negocio** | Arquitectura resiliente: la caída física de un nodo no interrumpe el servicio. **Zero Downtime real.** |
| 📊 **Previsibilidad Financiera** | Costes variables de nube pública → tarifa plana mensual predecible. |
| 🌱 **Sostenibilidad Tecnológica** | Alineados con la **Agenda 2030 (ODS 9 y 12)**: hardware refurbished y eficiencia de la contenerización. |

**SLA objetivo: 99,99% de disponibilidad.**

---

## 🏗️ Arquitectura

La infraestructura está diseñada para eliminar todos los puntos únicos de fallo (**SPOF — Single Point of Failure**). Cada capa tiene redundancia explícita.

```
                        ┌─────────────────────────────────┐
                        │         INTERNET (Usuarios)       │
                        └────────────────┬────────────────┘
                                         │ HTTPS
                                         ▼
                        ┌─────────────────────────────────┐
                        │       CLOUDFLARE TUNNELS         │
                        │   (Zero-Trust · Anti-DDoS · WAF) │
                        └────────────────┬────────────────┘
                                         │ Túnel Inverso Cifrado
                                         ▼
               ┌─────────────────────────────────────────────┐
               │          VIP (Keepalived + HAProxy)          │
               │     Balanceo L4 · Failover Automático        │
               └───────┬──────────────┬──────────────┬───────┘
                       ▼              ▼              ▼
              ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
              │  MASTER-01   │ │  MASTER-02   │ │  MASTER-03   │
              │  etcd · API  │ │  etcd · API  │ │  etcd · API  │
              └──────────────┘ └──────────────┘ └──────────────┘
                        │  Quórum Raft (impar = Anti-Split-Brain)
               ┌────────┴──────────────────────────────┐
               │         MetalLB L2 · Calico CNI        │
               └────┬──────────┬──────────┬──────────┬─┘
                    ▼          ▼          ▼          ▼
             ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
             │ WORKER-01│ │ WORKER-02│ │ WORKER-03│ │ WORKER-04│
             │ Pods     │ │ Pods     │ │ Pods     │ │ Pods     │
             └──────────┘ └──────────┘ └──────────┘ └──────────┘
                    │          │          │          │
               └────┴──────────┴──────────┴──────────┘
                                  │ iSCSI / NFS
                         ┌────────▼────────┐
                         │  NAS SYNOLOGY   │
                         │  Storage CSI    │
                         │  (Persistencia) │
                         └─────────────────┘
```

### Decisiones Arquitectónicas Clave

| Decisión | Justificación Técnica |
|---|---|
| **3 nodos Master (impar)** | El algoritmo de consenso **Raft** de etcd requiere quórum de mayoría estricta. Con 3 nodos se tolera la caída de 1 nodo sin Split-Brain. 4 nodos generaría empate irresolvible en partición de red. |
| **HAProxy + Keepalived (VIP)** | Elimina el SPOF del API Server. Si el Master activo cae, la **IP Virtual migra en segundos** al nodo de respaldo de forma completamente transparente para los clientes. |
| **Cloudflare Tunnels (Zero-Trust)** | Ningún puerto físico queda expuesto. La IP pública de la infraestructura está oculta. Cloudflare actúa como WAF y escudo Anti-DDoS perimetral. |
| **NAS Synology vía CSI (iSCSI/NFS)** | Los datos nunca residen en el nodo que ejecuta el Pod. Ante una reubicación del Pod por caída de nodo, el volumen persistente se monta automáticamente en el nuevo destino. |
| **Calico CNI** | Red de Pods con políticas de firewall interno (NetworkPolicies) para el aislamiento entre namespaces de clientes (Multitenancy). |
| **MetalLB (modo L2)** | Proveedor de LoadBalancer nativo para entornos Bare-Metal, habilitando IPs dedicadas para cada servicio expuesto. |

---

## 📁 Estructura del Repositorio

```
emi-cloud-iac/
│
├── 📂 scripts-automatizacion/       # Automatización y Self-Healing
│   ├── k8s-installer.sh             # Aprovisionamiento desatendido de nodos
│   ├── addwordpresscluster.bash     # Despliegue Multitenant de clientes
│   └── auto-metallb.sh             # Demonio Self-Healing de red (⭐ script estrella)
│
├── 📂 ha-control-plane/             # Alta Disponibilidad del Plano de Control
│   ├── haproxy.cfg                  # Balanceador L4 del API Server
│   └── keepalived.conf              # Gestor VRRP de la IP Virtual (VIP)
│
├── 📂 kubernetes-core/              # Componentes de Red y Almacenamiento
│   ├── metallb.yaml                 # LoadBalancer Bare-Metal (L2)
│   ├── synology-storageclass.yaml   # StorageClass CSI para NAS Synology
│   └── cloudflare.yaml             # Túneles Zero-Trust de red perimetral
│
├── 📂 monitorizacion/               # Stack de Observabilidad
│   └── grafana-monitor.yaml        # Prometheus + Grafana + Alertmanager
│
└── README.md
```

---

## ⚙️ Descripción Técnica de Componentes

### 📂 `/scripts-automatizacion/`

#### `k8s-installer.sh` — Aprovisionamiento Desatendido de Nodos

Script maestro de **scale-out horizontal** de la infraestructura. Transforma un servidor Ubuntu limpio en un nodo Kubernetes completamente integrado en el clúster en **menos de 3 minutos**, sin intervención manual.

**Flujo de operaciones:**
1. Audita el nodo remoto vía **SSH** para detectar instalaciones previas y prevenir sobreescrituras.
2. Calcula dinámicamente el **siguiente hostname disponible** en la secuencia del clúster (ej. `worker-05`).
3. Instala de forma desatendida: `containerd`, utilidades NFS y los binarios de Kubernetes (`kubeadm`, `kubelet`, `kubectl`).
4. Genera un **token criptográfico de unión** (`kubeadm token create`) desde el plano de control.
5. Inyecta el token en el nuevo nodo y ejecuta `kubeadm join` de forma completamente automatizada.

> **Caso de uso:** Ante un pico de demanda de clientes, el administrador escala la capacidad de cómputo añadiendo un nuevo servidor físico con un único comando.

---

#### `addwordpresscluster.bash` — Despliegue Multitenant de Clientes

Script de **onboarding automatizado** que despliega entornos aislados y completos de cliente (WordPress + MySQL) sobre la infraestructura compartida, implementando un modelo de **Multitenancy** seguro.

**Operaciones autónomas:**
- Verifica si el namespace del cliente ya existe para evitar colisiones.
- Calcula y reserva la **siguiente IP libre** en el pool de MetalLB.
- Genera dinámicamente manifiestos YAML completos (`Secrets`, `PVCs`, `Deployments`, `StatefulSets`) con prefijos únicos por cliente (ej. `mysql-pass-<cliente>`).
- Reclama volúmenes persistentes en el NAS Synology vía **CSI (iSCSI/NFS)**.
- Aplica toda la configuración al clúster con `kubectl apply` en un único paso.

> **Resultado:** Un entorno de producción completamente aislado, con base de datos propia y almacenamiento persistente dedicado, desplegado de forma reproducible en segundos.

---

#### `auto-metallb.sh` — Demonio Self-Healing de Red ⭐

El componente más avanzado del repositorio. Actúa como un **demonio de auto-reparación** que monitoriza continuamente la salud del pool de IPs de MetalLB. Resuelve el problema operativo crítico del agotamiento de direcciones IP virtuales sin tiempos de inactividad ni intervención humana.

**Características avanzadas:**

- 🔍 **Monitorización continua**: Detecta proactivamente cuándo el pool de IPs de MetalLB está próximo a agotarse.
- 🔧 **Auto-reparación (Self-Healing)**: Muta la API de Kubernetes en caliente (`kubectl edit IPAddressPool`) para expandir la subred asignada, desbloqueando automáticamente los servicios atascados en estado `<pending>`.
- 🏆 **Leader Election basado en VIP**: Implementa un mecanismo de elección de líder consultando la IP Virtual de Keepalived. Solo el Master activo (el que posee la VIP) ejecuta el proceso de expansión. Esto **previene el Split-Brain** y garantiza que la mutación de la API se aplique exactamente una vez, aunque el script se ejecute en los 3 Masters simultáneamente.

> **Impacto:** El clúster se administra a sí mismo ante escenarios de crecimiento, reduciendo la carga operativa y eliminando el riesgo de interrupción del servicio por un recurso agotado.

---

### 📂 `/ha-control-plane/`

#### `haproxy.cfg` — Balanceador de Carga L4 del API Server

Configuración del balanceador de carga **HAProxy** en modo TCP (Capa 4), responsable de distribuir el tráfico entrante al API Server de Kubernetes (puerto `6443`) entre los tres nodos Master disponibles.

Este componente es la primera línea de defensa contra la caída de un Master: si uno de los backends deja de responder a los health checks, HAProxy lo elimina automáticamente del pool de distribución sin afectar las conexiones activas de `kubectl` ni de los nodos Worker.

---

#### `keepalived.conf` — Gestor VRRP de la IP Virtual

Configuración del demonio **Keepalived**, que implementa el protocolo **VRRP (Virtual Router Redundancy Protocol)** para gestionar una **IP Virtual (VIP)** flotante entre los Masters.

**Comportamiento de failover:**
- El Master con mayor prioridad posee la VIP y es el punto de entrada activo.
- Los Masters secundarios monitorizan constantemente al primario mediante VRRP heartbeats.
- Si el Master activo falla (hardware, red o energía), la VIP migra **instantáneamente** al siguiente Master en orden de prioridad.
- Todo `kubectl`, Worker y cliente apunta siempre a la VIP, haciendo el failover completamente **transparente y sin downtime**.

---

### 📂 `/kubernetes-core/`

#### `metallb.yaml` — LoadBalancer Bare-Metal (L2)

Manifiesto de despliegue de **MetalLB** en modo Layer 2, incluyendo la definición del `IPAddressPool` y el `L2Advertisement`. Habilita el tipo de servicio `LoadBalancer` nativo en entornos Bare-Metal donde no existe un proveedor de nube que lo gestione, asignando IPs dedicadas y enrutables a cada servicio expuesto del clúster.

---

#### `synology-storageclass.yaml` — StorageClass CSI para NAS Synology

Definición de la **StorageClass** y los recursos CSI necesarios para integrar el NAS Synology como backend de almacenamiento persistente del clúster.

Permite el **aprovisionamiento dinámico** de volúmenes: cuando un Pod reclama un `PersistentVolumeClaim`, el controlador CSI negocia automáticamente con la API del NAS la creación de un nuevo **LUN iSCSI** o un **export NFS**, y lo monta en el nodo Worker correspondiente sin intervención manual.

**Garantía clave:** Los datos de MySQL y WordPress son independientes del nodo que ejecuta el Pod. Ante una reubicación por fallo de nodo, el volumen se reasigna y monta en el nuevo destino preservando la integridad total de los datos.

<img width="1398" height="356" alt="image" src="https://github.com/user-attachments/assets/70313072-b67a-4760-b108-e9bde1429add" />
<img width="1408" height="328" alt="image" src="https://github.com/user-attachments/assets/ce92faf2-7f61-4917-aeee-19b0718a3564" />

---

#### `cloudflare.yaml` — Túneles Zero-Trust de Red Perimetral

Manifiesto de despliegue del demonio **`cloudflared`**, que establece túneles inversos cifrados (TLS) desde el clúster hacia la red global de Cloudflare.

**Por qué Zero-Trust y no Port Forwarding:**

| Aspecto | Port Forwarding tradicional | Cloudflare Tunnels (Zero-Trust) |
|---|---|---|
| Exposición de IP pública | ✅ IP visible y escaneable | ❌ IP real completamente oculta |
| Protección DDoS | ❌ Nula | ✅ Mitigación automática en borde |
| Apertura de puertos físicos | ✅ Requiere NAT en router | ❌ No requiere ningún puerto abierto |
| WAF integrado | ❌ No | ✅ Sí, con rate limiting y bloqueo por firma |

> **Validado en pruebas de estrés:** Cloudflare detectó y bloqueó automáticamente una simulación de ataque DDoS Layer 7 (15.000 peticiones concurrentes simultáneas) sin que el hardware Bare-Metal registrase picos de CPU o RAM.

---

### 📂 `/monitorizacion/`

#### `grafana-monitor.yaml` — Stack de Observabilidad Completo

Manifiesto de despliegue del stack `kube-prometheus-stack`, que incluye **Prometheus**, **Grafana** y **Alertmanager**, con volúmenes persistentes iSCSI para garantizar la retención de métricas históricas entre reinicios.

**Capacidades implementadas:**

- 📈 **Métricas avanzadas con PromQL**: Consultas con expresiones regulares para segmentar el consumo de CPU/RAM entre Masters y Workers. Diferenciación de **IOPS vs. Throughput** de disco para detectar throttling antes de que impacte a los clientes.
- 🌐 **Métricas de red bidireccionales**: Monitorización de tráfico Rx/Tx por nodo para anticipar saturación de ancho de banda.
- 🤖 **Alertas en tiempo real via Telegram**: Alertmanager configurado con un bot de Telegram usando plantillas Go con HTML enriquecido. Distingue visualmente entre alertas críticas de caída de nodo y eventos de recuperación.
- 🔕 **Lógica anti-falsos-positivos**: Umbrales PromQL calibrados con `== 0` para evitar alertas durante reinicios de servidor y correcta detección de `CrashLoopBackOff` en contenedores de clientes.
- 🕐 **Zona horaria local**: Volúmenes ReadOnly de `/etc/localtime` inyectados en los contenedores de Grafana y Alertmanager para timestamps correctos en `Europe/Madrid`.

<img width="857" height="837" alt="alerta" src="https://github.com/user-attachments/assets/854ce7d6-f88b-4ee5-8e82-04dbc7ab4ccd" />
<img width="1297" height="561" alt="image" src="https://github.com/user-attachments/assets/a80d52a0-caef-4b60-830a-429fb725939e" />

---

## 🧪 Resultados de las Pruebas de Estrés

### Prueba de Alta Disponibilidad (Fallo Físico de Nodo)

Se simuló un corte eléctrico abrupto eliminando físicamente la alimentación de `worker-04` sin aviso previo.

| Indicador | Resultado |
|---|---|
| ⚡ Detección de caída | Kubernetes marcó el nodo como `NotReady` en **segundos** |
| 📲 Notificación | Alertmanager envió alerta `NODO CAÍDO` a Telegram en **tiempo real** |
| 🔄 Reprogramación de Pods | Los Pods de `worker-04` se redistribuyeron automáticamente en workers 01, 02 y 03 |
| 💾 Persistencia de datos | Datos de MySQL y WordPress permanecieron **íntegros** (NAS Synology) |
| 🌐 Continuidad web | **Tiempo de inactividad: 0 segundos** — Alta Disponibilidad real validada |

### Prueba de Estrés y Seguridad Perimetral (Simulación DDoS Layer 7)

15.000 peticiones HTTP concurrentes contra los 3 dominios activos simultáneamente (`ab -n 5000 -c 100`).

| Indicador | Resultado |
|---|---|
| 🖥️ CPU Workers durante el ataque | **12,20%** — Throttling nulo |
| 🖥️ CPU Masters durante el ataque | **4,47%** — Estabilidad total |
| 🛡️ Respuesta perimetral | Cloudflare detectó la firma del ataque y aplicó **Rate Limiting** automático, cortando la conexión SSL de la IP atacante en los 3 dominios simultáneamente |

<img width="1286" height="577" alt="image" src="https://github.com/user-attachments/assets/3e504b68-4534-467c-b4d7-ec7c68527930" />

---

## 💰 Viabilidad Económica (ROI)

| Concepto | Coste |
|---|---|
| **CAPEX total (infraestructura física)** | ~9.900 € |
| **Equivalente en AWS** (EKS + Workers + Storage) | ~790 €/mes (~9.480 €/año) |
| **Punto de equilibrio** | **12,5 meses** |
| **Beneficio neto** (15 clientes × 120 €/mes − OPEX) | **1.500 €/mes** |
| **Recuperación de inversión con ingresos** | **< 7 meses** |

> A partir del mes 13, la infraestructura On-Premise es **radicalmente más rentable** que el equivalente en nube pública.

---

## 🌱 Compromiso con la Sostenibilidad (RSC)

Alineados con la **Agenda 2030**:

- ♻️ **ODS 12 — Consumo Responsable:** Más del 60% del clúster está compuesto por hardware bare-metal **refurbished**, reduciendo activamente la generación de residuos electrónicos (RAEE).
- 🔋 **ODS 9 — Industria e Innovación:** Exigimos a nuestro proveedor de Datacenter un **PUE óptimo** y uso de energía 100% renovable.
- 🎓 **Zero-Waste IT:** Programa de donación de hardware obsoleto a centros de Formación Profesional para uso educativo.
- 🤝 **Hosting Solidario:** Espacio reservado de alta disponibilidad gratuito para tres ONGs locales al año.

---

## 🗺️ Líneas Futuras (Fase 2)

- [ ] **Disaster Recovery (DR):** Integración de **Velero** para backups automáticos de volúmenes NAS y estado de etcd hacia almacenamiento S3 externo.
- [ ] **Zero-Trust interno:** Network Policies avanzadas en Calico para aislamiento a nivel de firewall entre namespaces de clientes.
- [ ] **GitOps (CI/CD):** Migración de scripts Bash hacia despliegue declarativo automatizado con **ArgoCD**.

---

## 📚 Referencias

- [Kubernetes Official Documentation](https://kubernetes.io/docs/)
- [MetalLB Documentation](https://metallb.universe.tf/)
- [Calico / Tigera Documentation](https://docs.tigera.io/calico/latest/about/)
- [Synology CSI Driver](https://github.com/SynologyOpenSource/synology-csi)
- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

---

## 📄 Licencia

Este proyecto está publicado bajo licencia **MIT**. Puedes usar, modificar y distribuir el código con la condición de mantener la atribución a los autores originales.

---

<div align="center">

**Construido con 🔧 y mucha resiliencia por Edison, Izan y Marc**

*Proyecto Final de Grado · ASIX · Curso 2025–2026*

</div>
