#!/bin/bash
# Pre-apply hook to deploy git-daemon service for serving test repos

set -e

TASK_FILE=$1
NAMESPACE=$2

echo "INFO: Deploying git-daemon service to serve test repositories"

# Create PVC for git repositories
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: git-repos
  namespace: ${NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# Create git-daemon deployment
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: git-daemon
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: git-daemon
  template:
    metadata:
      labels:
        app: git-daemon
    spec:
      containers:
      - name: git-daemon
        image: alpine:latest
        command:
          - /bin/sh
          - -c
          - |
            echo "Installing git-daemon..."
            apk add --no-cache git-daemon
            echo "Waiting for git repositories to be created..."
            while [ ! -d /git-repos/.initialized ]; do
              sleep 1
            done
            echo "Starting git daemon to serve repositories from /git-repos"
            git daemon --verbose --export-all --base-path=/git-repos --reuseaddr --listen=0.0.0.0
        ports:
        - containerPort: 9418
          name: git
        volumeMounts:
        - name: git-repos
          mountPath: /git-repos
      volumes:
      - name: git-repos
        persistentVolumeClaim:
          claimName: git-repos
EOF

# Create git-daemon service
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: git-daemon
  namespace: ${NAMESPACE}
spec:
  selector:
    app: git-daemon
  ports:
  - port: 9418
    targetPort: 9418
    protocol: TCP
    name: git
EOF

echo "INFO: Git daemon service deployed. The yaml-lint task will be used unmodified."
cat "$TASK_FILE"
