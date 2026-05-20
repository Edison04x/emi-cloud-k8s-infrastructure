#!/bin/bash

# ==============================================================================
# SCRIPT: addwordpresscluster.bash
# DESCRIPCION: Despliega dinamicamente un entorno Multitenant (WP + MySQL)
#              con almacenamiento persistente CSI y red balanceada.
# ==============================================================================

read -p "Nombre del tenant/cliente (se añadirá el prefijo 'mysql-'): " nombre

if [ -z "$nombre" ]; then
    echo "[ERROR] Debes introducir un nombre de cliente válido."
    exit 1
fi

FULL_NAME="mysql-$nombre"
WP_NAME="wordpress-$nombre"

read -p "Numero de replicas de WordPress? [3]: " rep
rep=${rep:-3}

read -p "Numero de replicas de MySQL? [3]: " mysql_rep
mysql_rep=${mysql_rep:-2}

# Calculo dinamico de la siguiente IP disponible
ULTIMA_IP=$(kubectl get svc -A -o jsonpath='{range .items[*]}{.status.loadBalancer.ingress[0].ip}{"\n"}{end}' | grep -v "^$" | sort -V | tail -n 1)

if [ -n "$ULTIMA_IP" ]; then
    echo "[INFO] La IP más alta en uso actualmente es: $ULTIMA_IP"
    BASE_IP=$(echo $ULTIMA_IP | cut -d. -f1-3)
    ULTIMO_OCTETO=$(echo $ULTIMA_IP | cut -d. -f4)
    SIGUIENTE_IP="$BASE_IP.$((ULTIMO_OCTETO + 1))"

    read -p "Asignar IP LoadBalancer para WordPress? [$SIGUIENTE_IP]: " ip
    ip=${ip:-$SIGUIENTE_IP}
else
    read -p "Asignar IP LoadBalancer para WordPress? (ej: 10.110.19.103): " ip
fi

# Validaciones de pre-despliegue
if helm list -q | grep -w "$FULL_NAME" > /dev/null; then
    echo "[ERROR] El release '$FULL_NAME' ya existe en Helm."
    exit 1
fi

if kubectl get pvc | grep -w "$FULL_NAME" > /dev/null; then
    echo "[WARN] Se han detectado PersistentVolumeClaims huérfanos para $FULL_NAME."
    echo "[WARN] Por favor, purga el almacenamiento residual antes de continuar."
    exit 1
fi

echo "[INFO] Generando configuración de MySQL para el tenant '$FULL_NAME'..."
MYSQL_VALUES_FILE="/home/asix/k8s-configyaml-scripts/archivos-kubectl-yaml/values-${FULL_NAME}.yaml"

cat <<EOF > "$MYSQL_VALUES_FILE"
global:
  security:
    allowInsecureImages: true
architecture: replication
image:
  registry: public.ecr.aws
  repository: bitnami/mysql
  tag: "8.4.0"
  pullPolicy: IfNotPresent
auth:
  rootPassword: "<DB_ROOT_PASSWORD>"
  database: "db_${nombre}"
  username: "db_user"
  password: "<DB_USER_PASSWORD>"
primary:
  persistence:
    enabled: true
    size: 20Gi
    storageClass: ""
secondary:
  replicaCount: ${mysql_rep}
  persistence:
    enabled: true
    size: 20Gi
    storageClass: ""
EOF

echo "[INFO] Desplegando clúster MySQL ($mysql_rep réplicas)..."
helm install "$FULL_NAME" bitnami/mysql -f "$MYSQL_VALUES_FILE" > /dev/null

echo "[INFO] Generando manifiestos de Kubernetes para WordPress..."
YAML_FILE="/home/asix/k8s-configyaml-scripts/archivos-kubectl-yaml/${WP_NAME}.yaml"

cat <<EOF > "$YAML_FILE"
apiVersion: v1
kind: Secret
metadata:
  name: mysql-pass-${nombre}
type: Opaque
data:
  password: <BASE64_ENCODED_PASSWORD>
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv-${nombre}
spec:
  storageClassName: ""
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteMany
  nfs:
    server: 10.110.19.180
    path: "/volume1/k8s-nfs-volumes"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-pvc-${nombre}
spec:
  storageClassName: ""
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 20Gi
  volumeName: nfs-pv-${nombre}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${WP_NAME}
  labels:
    app: ${WP_NAME}
spec:
  replicas: ${rep}
  selector:
    matchLabels:
      app: ${WP_NAME}
      tier: frontend
  template:
    metadata:
      labels:
        app: ${WP_NAME}
        tier: frontend
    spec:
      containers:
      - image: wordpress:latest
        name: wordpress
        env:
        - name: WORDPRESS_DB_HOST
          value: ${FULL_NAME}-primary
        - name: WORDPRESS_DB_USER
          value: db_user
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-pass-${nombre}
              key: password
        - name: WORDPRESS_DB_NAME
          value: db_${nombre}
        ports:
        - containerPort: 80
          name: wordpress
        volumeMounts:
        - name: wordpress-persistent-storage
          mountPath: /var/www/html
          subPath: web-${nombre}
      volumes:
      - name: wordpress-persistent-storage
        persistentVolumeClaim:
          claimName: nfs-pvc-${nombre}
---
apiVersion: v1
kind: Service
metadata:
  name: ${WP_NAME}
  labels:
    app: ${WP_NAME}
  annotations:
    metallb.universe.tf/loadBalancerIPs: ${ip}
spec:
  ports:
    - port: 80
  selector:
    app: ${WP_NAME}
    tier: frontend
  type: LoadBalancer
EOF

echo "[INFO] Aplicando manifiestos YAML en el clúster..."
kubectl apply -f "$YAML_FILE"

echo "[SUCCESS] Despliegue completado."
echo "[INFO] El servicio estará disponible en http://$ip una vez se aprovisionen los volúmenes CSI."