#!/bin/bash
# Pre-apply hook: deploy a mock Jenkins HTTPS server and credentials secret.
# Patches the task YAML to mount the CA cert for the positive test.

set -o errexit -o nounset -o pipefail

TASK_FILE=$1
NAMESPACE=$2

CERT_DIR=$(mktemp -d)
trap 'rm -rf "${CERT_DIR}"' EXIT

echo "INFO: Creating jenkins-credentials secret in ${NAMESPACE}"
kubectl create secret generic jenkins-credentials \
  --namespace="${NAMESPACE}" \
  --from-literal=username=testuser \
  --from-literal=apitoken=testapitoken \
  --dry-run=client -o yaml | kubectl apply -f -

echo "INFO: Generating self-signed TLS certificate for mock Jenkins"
openssl req -x509 -newkey rsa:2048 \
  -keyout "${CERT_DIR}/tls.key" -out "${CERT_DIR}/tls.crt" \
  -days 1 -nodes \
  -subj "/CN=mock-jenkins.${NAMESPACE}.svc.cluster.local" \
  -addext "subjectAltName=DNS:mock-jenkins.${NAMESPACE}.svc.cluster.local" \
  2>/dev/null

echo "INFO: Storing CA cert in ConfigMap and TLS keypair in Secret"
kubectl create configmap jenkins-ca-cert \
  --namespace="${NAMESPACE}" \
  --from-file=ca.crt="${CERT_DIR}/tls.crt" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret tls mock-jenkins-tls \
  --namespace="${NAMESPACE}" \
  --cert="${CERT_DIR}/tls.crt" \
  --key="${CERT_DIR}/tls.key" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "INFO: Deploying mock Jenkins HTTPS server"
kubectl apply -n "${NAMESPACE}" -f - <<'PYEOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: mock-jenkins-server
data:
  server.py: |
    #!/usr/bin/env python3
    """Minimal HTTPS server mimicking Jenkins build API."""
    import http.server
    import ssl
    import sys

    CERT_FILE = "/tls/tls.crt"
    KEY_FILE = "/tls/tls.key"

    class JenkinsHandler(http.server.BaseHTTPRequestHandler):
        def do_POST(self):
            auth = self.headers.get("Authorization", "")
            if not auth.startswith("Basic "):
                self.send_response(401)
                self.end_headers()
                self.wfile.write(b"Unauthorized")
                return
            if "/build" in self.path:
                self.send_response(201)
                self.end_headers()
                self.wfile.write(b"Queued")
            else:
                self.send_response(404)
                self.end_headers()
                self.wfile.write(b"Not Found")

        def log_message(self, fmt, *args):
            print(fmt % args, flush=True)

    if __name__ == "__main__":
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(CERT_FILE, KEY_FILE)

        server = http.server.HTTPServer(("0.0.0.0", 8443), JenkinsHandler)
        server.socket = context.wrap_socket(server.socket, server_side=True)
        print("Mock Jenkins listening on :8443", flush=True)
        server.serve_forever()
PYEOF

kubectl apply -n "${NAMESPACE}" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mock-jenkins
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mock-jenkins
  template:
    metadata:
      labels:
        app: mock-jenkins
    spec:
      containers:
        - name: mock-jenkins
          image: registry.access.redhat.com/ubi8/ubi:8.2
          command:
            - /usr/libexec/platform-python
            - /scripts/server.py
          ports:
            - containerPort: 8443
          volumeMounts:
            - name: tls-certs
              mountPath: /tls
              readOnly: true
            - name: server-script
              mountPath: /scripts
              readOnly: true
      volumes:
        - name: tls-certs
          secret:
            secretName: mock-jenkins-tls
        - name: server-script
          configMap:
            name: mock-jenkins-server
---
apiVersion: v1
kind: Service
metadata:
  name: mock-jenkins
  namespace: ${NAMESPACE}
spec:
  selector:
    app: mock-jenkins
  ports:
    - port: 8443
      targetPort: 8443
      protocol: TCP
EOF

echo "INFO: Waiting for mock-jenkins deployment to be ready"
kubectl rollout status deployment/mock-jenkins -n "${NAMESPACE}" --timeout=120s

echo "INFO: Patching task YAML to mount CA cert ConfigMap"
yq -i '.spec.volumes += [{"name": "jenkins-ca-cert", "configMap": {"name": "jenkins-ca-cert"}}]' \
  "${TASK_FILE}"
yq -i '.spec.steps[0].volumeMounts += [{"name": "jenkins-ca-cert", "mountPath": "/ca", "readOnly": true}]' \
  "${TASK_FILE}"

echo "INFO: Mock Jenkins server is ready, task patched with CA cert volume"
