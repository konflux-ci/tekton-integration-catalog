#!/bin/bash
function queue() {
  local TARGET="${1}"
  shift
  local LIVE
  LIVE="$(jobs | wc -l)"
  while [[ "${LIVE}" -ge 45 ]]; do
    sleep 1
    LIVE="$(jobs | wc -l)"
  done
  echo "${@}"
  if [[ -n "${FILTER:-}" ]]; then
    "${@}" | "${FILTER}" >"${TARGET}" &
  else
    "${@}" >"${TARGET}" &
  fi
}

export ARTIFACT_DIR="${ARTIFACT_DIR:-.}"

# Ensure the directory exists
mkdir -p "$ARTIFACT_DIR"

echo "Gathering artifacts ..."
mkdir -p ${ARTIFACT_DIR}/pods

oc --insecure-skip-tls-verify --request-timeout=5s get nodes -o jsonpath --template '{range .items[*]}{.metadata.name}{"\n"}{end}' > /tmp/nodes
oc --insecure-skip-tls-verify --request-timeout=5s get pods --all-namespaces --template '{{ range .items }}{{ $name := .metadata.name }}{{ $ns := .metadata.namespace }}{{ range .spec.containers }}-n {{ $ns }} {{ $name }} -c {{ .name }}{{ "\n" }}{{ end }}{{ range .spec.initContainers }}-n {{ $ns }} {{ $name }} -c {{ .name }}{{ "\n" }}{{ end }}{{ end }}' > /tmp/containers
oc --insecure-skip-tls-verify --request-timeout=5s get pods -l openshift.io/component=api --all-namespaces --template '{{ range .items }}-n {{ .metadata.namespace }} {{ .metadata.name }}{{ "\n" }}{{ end }}' > /tmp/pods-api

queue ${ARTIFACT_DIR}/apiservices.json oc --insecure-skip-tls-verify --request-timeout=5s get apiservices -o json
queue ${ARTIFACT_DIR}/clusteroperators.json oc --insecure-skip-tls-verify --request-timeout=5s get clusteroperators -o json
queue ${ARTIFACT_DIR}/clusterversion.json oc --insecure-skip-tls-verify --request-timeout=5s get clusterversion -o json
queue ${ARTIFACT_DIR}/configmaps.json oc --insecure-skip-tls-verify --request-timeout=5s get configmaps --all-namespaces -o json
queue ${ARTIFACT_DIR}/credentialsrequests.json oc --insecure-skip-tls-verify --request-timeout=5s get credentialsrequests --all-namespaces -o json
queue ${ARTIFACT_DIR}/csr.json oc --insecure-skip-tls-verify --request-timeout=5s get csr -o json
queue ${ARTIFACT_DIR}/endpoints.json oc --insecure-skip-tls-verify --request-timeout=5s get endpoints --all-namespaces -o json
FILTER=gzip queue ${ARTIFACT_DIR}/deployments.json.gz oc --insecure-skip-tls-verify --request-timeout=5s get deployments --all-namespaces -o json
FILTER=gzip queue ${ARTIFACT_DIR}/daemonsets.json.gz oc --insecure-skip-tls-verify --request-timeout=5s get daemonsets --all-namespaces -o json
queue ${ARTIFACT_DIR}/events.json oc --insecure-skip-tls-verify --request-timeout=5s get events --all-namespaces -o json
queue ${ARTIFACT_DIR}/kubeapiserver.json oc --insecure-skip-tls-verify --request-timeout=5s get kubeapiserver -o json
queue ${ARTIFACT_DIR}/kubecontrollermanager.json oc --insecure-skip-tls-verify --request-timeout=5s get kubecontrollermanager -o json
queue ${ARTIFACT_DIR}/machineconfigpools.json oc --insecure-skip-tls-verify --request-timeout=5s get machineconfigpools -o json
queue ${ARTIFACT_DIR}/machineconfigs.json oc --insecure-skip-tls-verify --request-timeout=5s get machineconfigs -o json
queue ${ARTIFACT_DIR}/controlplanemachinesets.json oc --insecure-skip-tls-verify --request-timeout=5s get controlplanemachinesets -A -o json
queue ${ARTIFACT_DIR}/machinesets.json oc --insecure-skip-tls-verify --request-timeout=5s get machinesets -A -o json
queue ${ARTIFACT_DIR}/machines.json oc --insecure-skip-tls-verify --request-timeout=5s get machines -A -o json
queue ${ARTIFACT_DIR}/namespaces.json oc --insecure-skip-tls-verify --request-timeout=5s get namespaces -o json
queue ${ARTIFACT_DIR}/nodes.json oc --insecure-skip-tls-verify --request-timeout=5s get nodes -o json
queue ${ARTIFACT_DIR}/openshiftapiserver.json oc --insecure-skip-tls-verify --request-timeout=5s get openshiftapiserver -o json
queue ${ARTIFACT_DIR}/persistentvolumes.json oc --insecure-skip-tls-verify --request-timeout=5s get persistentvolumes --all-namespaces -o json
queue ${ARTIFACT_DIR}/persistentvolumeclaims.json oc --insecure-skip-tls-verify --request-timeout=5s get persistentvolumeclaims --all-namespaces -o json
FILTER=gzip queue ${ARTIFACT_DIR}/replicasets.json.gz oc --insecure-skip-tls-verify --request-timeout=5s get replicasets --all-namespaces -o json
queue ${ARTIFACT_DIR}/rolebindings.json oc --insecure-skip-tls-verify --request-timeout=5s get rolebindings --all-namespaces -o json
queue ${ARTIFACT_DIR}/roles.json oc --insecure-skip-tls-verify --request-timeout=5s get roles --all-namespaces -o json
queue ${ARTIFACT_DIR}/services.json oc --insecure-skip-tls-verify --request-timeout=5s get services --all-namespaces -o json
FILTER=gzip queue ${ARTIFACT_DIR}/statefulsets.json.gz oc --insecure-skip-tls-verify --request-timeout=5s get statefulsets --all-namespaces -o json
queue ${ARTIFACT_DIR}/routes.json oc --insecure-skip-tls-verify --request-timeout=5s get routes --all-namespaces -o json
queue ${ARTIFACT_DIR}/subscriptions.json oc --insecure-skip-tls-verify --request-timeout=5s get subscriptions --all-namespaces -o json
queue ${ARTIFACT_DIR}/clusterserviceversions.json oc --insecure-skip-tls-verify --request-timeout=5s get clusterserviceversions --all-namespaces -o json
queue ${ARTIFACT_DIR}/releaseinfo.json oc --insecure-skip-tls-verify --request-timeout=5s adm release info -o json
queue ${ARTIFACT_DIR}/clusterrolebindings.json oc --insecure-skip-tls-verify --request-timeout=5s get clusterrolebindings --all-namespaces -o json

# ArgoCD resources
queue ${ARTIFACT_DIR}/applications_argoproj.json  oc --insecure-skip-tls-verify --request-timeout=5s get applications.argoproj.io --all-namespaces -o json
queue ${ARTIFACT_DIR}/applicationsets.json  oc --insecure-skip-tls-verify --request-timeout=5s get applicationsets.argoproj.io --all-namespaces -o json
queue ${ARTIFACT_DIR}/appprojects.json  oc --insecure-skip-tls-verify --request-timeout=5s get appprojects.argoproj.io --all-namespaces -o json
queue ${ARTIFACT_DIR}/argocds.json  oc --insecure-skip-tls-verify --request-timeout=5s get argocds.argoproj.io --all-namespaces -o json

# Tekton resources
queue ${ARTIFACT_DIR}/repositories.json  oc --insecure-skip-tls-verify --request-timeout=5s get repositories.pipelinesascode.tekton.dev --all-namespaces -o json
queue ${ARTIFACT_DIR}/pipelines.json  oc --insecure-skip-tls-verify --request-timeout=5s get pipelines.tekton.dev --all-namespaces -o json
queue ${ARTIFACT_DIR}/eventlisteners.json  oc --insecure-skip-tls-verify --request-timeout=5s get eventlisteners.triggers.tekton.dev --all-namespaces -o json
queue ${ARTIFACT_DIR}/triggerbindings.json  oc --insecure-skip-tls-verify --request-timeout=5s get triggerbindings.triggers.tekton.dev --all-namespaces -o json

# Appstudio resources
queue ${ARTIFACT_DIR}/applications_appstudio.json  oc --insecure-skip-tls-verify --request-timeout=5s get applications.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/buildpipelineselectors.json  oc --insecure-skip-tls-verify --request-timeout=5s get buildpipelineselectors.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/componentdetectionqueries.json  oc --insecure-skip-tls-verify --request-timeout=5s get componentdetectionqueries.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/components.json  oc --insecure-skip-tls-verify --request-timeout=5s get components.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/deploymenttargetclaims.json  oc --insecure-skip-tls-verify --request-timeout=5s get deploymenttargetclaims.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/deploymenttargetclasses.json  oc --insecure-skip-tls-verify --request-timeout=5s get deploymenttargetclasses.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/deploymenttargets.json  oc --insecure-skip-tls-verify --request-timeout=5s get deploymenttargets.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/enterprisecontractpolicies.json  oc --insecure-skip-tls-verify --request-timeout=5s get enterprisecontractpolicies.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/environments.json  oc --insecure-skip-tls-verify --request-timeout=5s get environments.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/integrationtestscenarios.json  oc --insecure-skip-tls-verify --request-timeout=5s get integrationtestscenarios.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/internalrequests.json  oc --insecure-skip-tls-verify --request-timeout=5s get internalrequests.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/promotionruns.json  oc --insecure-skip-tls-verify --request-timeout=5s get promotionruns.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/releaseplanadmissions.json  oc --insecure-skip-tls-verify --request-timeout=5s get releaseplanadmissions.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/releaseplans.json  oc --insecure-skip-tls-verify --request-timeout=5s get releaseplans.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/releases.json  oc --insecure-skip-tls-verify --request-timeout=5s get releases.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/releasestrategies.json  oc --insecure-skip-tls-verify --request-timeout=5s get releasestrategies.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/snapshotenvironmentbindings.json  oc --insecure-skip-tls-verify --request-timeout=5s get snapshotenvironmentbindings.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/snapshots.json  oc --insecure-skip-tls-verify --request-timeout=5s get snapshots.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/spiaccesschecks.json  oc --insecure-skip-tls-verify --request-timeout=5s get spiaccesschecks.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/spiaccesstokenbindings.json  oc --insecure-skip-tls-verify --request-timeout=5s get spiaccesstokenbindings.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/spiaccesstokendataupdates.json  oc --insecure-skip-tls-verify --request-timeout=5s get spiaccesstokendataupdates.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/spiaccesstokens.json  oc --insecure-skip-tls-verify --request-timeout=5s get spiaccesstokens.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/spifilecontentrequests.json  oc --insecure-skip-tls-verify --request-timeout=5s get spifilecontentrequests.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/remotesecrets.json oc --insecure-skip-tls-verify --request-timeout=5s get remotesecrets.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/imagerepositories.json  oc --insecure-skip-tls-verify --request-timeout=5s get imagerepositories.components.appstudio.redhat.com --all-namespaces -o json

# JBS resources (jvm-build-service)
queue ${ARTIFACT_DIR}/artifactbuilds.json  oc --insecure-skip-tls-verify --request-timeout=5s get artifactbuilds.jvmbuildservice.io --all-namespaces -o json
queue ${ARTIFACT_DIR}/dependencybuilds.json  oc --insecure-skip-tls-verify --request-timeout=5s get dependencybuilds.jvmbuildservice.io --all-namespaces -o json
queue ${ARTIFACT_DIR}/jbsconfigs.json  oc --insecure-skip-tls-verify --request-timeout=5s get jbsconfigs.jvmbuildservice.io --all-namespaces -o json
queue ${ARTIFACT_DIR}/rebuiltartifacts.json  oc --insecure-skip-tls-verify --request-timeout=5s get rebuiltartifacts.jvmbuildservice.io --all-namespaces -o json
queue ${ARTIFACT_DIR}/systemconfigs.json  oc --insecure-skip-tls-verify --request-timeout=5s get systemconfigs.jvmbuildservice.io --all-namespaces -o json

# ArgoCD resources
queue ${ARTIFACT_DIR}/applications_argoproj.json  oc --insecure-skip-tls-verify --request-timeout=5s get applications.argoproj.io --all-namespaces -o json
queue ${ARTIFACT_DIR}/applicationsets.json  oc --insecure-skip-tls-verify --request-timeout=5s get applicationsets.argoproj.io --all-namespaces -o json
queue ${ARTIFACT_DIR}/appprojects.json  oc --insecure-skip-tls-verify --request-timeout=5s get appprojects.argoproj.io --all-namespaces -o json
queue ${ARTIFACT_DIR}/argocds.json  oc --insecure-skip-tls-verify --request-timeout=5s get argocds.argoproj.io --all-namespaces -o json

# Managed-gitops resources
queue ${ARTIFACT_DIR}/gitopsdeploymentmanagedenvironments.json  oc --insecure-skip-tls-verify --request-timeout=5s get gitopsdeploymentmanagedenvironments.managed-gitops.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/gitopsdeploymentrepositorycredentials.json  oc --insecure-skip-tls-verify --request-timeout=5s get gitopsdeploymentrepositorycredentials.managed-gitops.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/gitopsdeployments.json  oc --insecure-skip-tls-verify --request-timeout=5s get gitopsdeployments.managed-gitops.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/gitopsdeploymentsyncruns.json  oc --insecure-skip-tls-verify --request-timeout=5s get gitopsdeploymentsyncruns.managed-gitops.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/operations.json  oc --insecure-skip-tls-verify --request-timeout=5s get operations.managed-gitops.redhat.com --all-namespaces -o json

# Tekton resources
queue ${ARTIFACT_DIR}/repositories.json  oc --insecure-skip-tls-verify --request-timeout=5s get repositories.pipelinesascode.tekton.dev --all-namespaces -o json
queue ${ARTIFACT_DIR}/resolutionrequests.json  oc --insecure-skip-tls-verify --request-timeout=5s get resolutionrequests.resolution.tekton.dev --all-namespaces -o json
queue ${ARTIFACT_DIR}/pipelineresources.json  oc --insecure-skip-tls-verify --request-timeout=5s get pipelineresources.tekton.dev --all-namespaces -o json
queue ${ARTIFACT_DIR}/pipelineruns.json  oc --insecure-skip-tls-verify --request-timeout=5s get pipelineruns.tekton.dev --all-namespaces -o json
queue ${ARTIFACT_DIR}/pipelines.json  oc --insecure-skip-tls-verify --request-timeout=5s get pipelines.tekton.dev --all-namespaces -o json
queue ${ARTIFACT_DIR}/runs.json  oc --insecure-skip-tls-verify --request-timeout=5s get runs.tekton.dev --all-namespaces -o json
queue ${ARTIFACT_DIR}/taskruns.json  oc --insecure-skip-tls-verify --request-timeout=5s get taskruns.tekton.dev --all-namespaces -o json
queue ${ARTIFACT_DIR}/tasks.json  oc --insecure-skip-tls-verify --request-timeout=5s get tasks.tekton.dev --all-namespaces -o json
queue ${ARTIFACT_DIR}/eventlisteners.json  oc --insecure-skip-tls-verify --request-timeout=5s get eventlisteners.triggers.tekton.dev --all-namespaces -o json
queue ${ARTIFACT_DIR}/triggerbindings.json  oc --insecure-skip-tls-verify --request-timeout=5s get triggerbindings.triggers.tekton.dev --all-namespaces -o json
queue ${ARTIFACT_DIR}/triggers.json  oc --insecure-skip-tls-verify --request-timeout=5s get triggers.triggers.tekton.dev --all-namespaces -o json
queue ${ARTIFACT_DIR}/triggertemplates.json  oc --insecure-skip-tls-verify --request-timeout=5s get triggertemplates.triggers.tekton.dev --all-namespaces -o json

# Toolchain resources
queue ${ARTIFACT_DIR}/bannedusers.json  oc --insecure-skip-tls-verify --request-timeout=5s get bannedusers.toolchain.dev.openshift.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/masteruserrecords.json  oc --insecure-skip-tls-verify --request-timeout=5s get masteruserrecords.toolchain.dev.openshift.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/memberoperatorconfigs.json  oc --insecure-skip-tls-verify --request-timeout=5s get memberoperatorconfigs.toolchain.dev.openshift.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/memberstatuses.json  oc --insecure-skip-tls-verify --request-timeout=5s get memberstatuses.toolchain.dev.openshift.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/notifications.json  oc --insecure-skip-tls-verify --request-timeout=5s get notifications.toolchain.dev.openshift.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/nstemplatesets.json  oc --insecure-skip-tls-verify --request-timeout=5s get nstemplatesets.toolchain.dev.openshift.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/nstemplatetiers.json  oc --insecure-skip-tls-verify --request-timeout=5s get nstemplatetiers.toolchain.dev.openshift.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/socialevents.json  oc --insecure-skip-tls-verify --request-timeout=5s get socialevents.toolchain.dev.openshift.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/spacebindings.json  oc --insecure-skip-tls-verify --request-timeout=5s get spacebindings.toolchain.dev.openshift.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/spacerequests.json  oc --insecure-skip-tls-verify --request-timeout=5s get spacerequests.toolchain.dev.openshift.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/spaces.json  oc --insecure-skip-tls-verify --request-timeout=5s get spaces.toolchain.dev.openshift.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/tiertemplates.json  oc --insecure-skip-tls-verify --request-timeout=5s get tiertemplates.toolchain.dev.openshift.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/toolchainclusters.json  oc --insecure-skip-tls-verify --request-timeout=5s get toolchainclusters.toolchain.dev.openshift.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/toolchainconfigs.json  oc --insecure-skip-tls-verify --request-timeout=5s get toolchainconfigs.toolchain.dev.openshift.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/toolchainstatuses.json  oc --insecure-skip-tls-verify --request-timeout=5s get toolchainstatuses.toolchain.dev.openshift.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/useraccounts.json  oc --insecure-skip-tls-verify --request-timeout=5s get useraccounts.toolchain.dev.openshift.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/usersignups.json  oc --insecure-skip-tls-verify --request-timeout=5s get usersignups.toolchain.dev.openshift.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/usertiers.json  oc --insecure-skip-tls-verify --request-timeout=5s get usertiers.toolchain.dev.openshift.com --all-namespaces -o json

# Non-namespaced resources
queue ${ARTIFACT_DIR}/idlers.json  oc --insecure-skip-tls-verify --request-timeout=5s get idlers.toolchain.dev.openshift.com -o json
queue ${ARTIFACT_DIR}/tektonaddons.json  oc --insecure-skip-tls-verify --request-timeout=5s get tektonaddons.operator.tekton.dev -o json
queue ${ARTIFACT_DIR}/tektonchains.json  oc --insecure-skip-tls-verify --request-timeout=5s get tektonchains.operator.tekton.dev -o json
queue ${ARTIFACT_DIR}/tektonconfigs.json  oc --insecure-skip-tls-verify --request-timeout=5s get tektonconfigs.operator.tekton.dev -o json
queue ${ARTIFACT_DIR}/tektonhubs.json  oc --insecure-skip-tls-verify --request-timeout=5s get tektonhubs.operator.tekton.dev -o json
queue ${ARTIFACT_DIR}/tektoninstallersets.json  oc --insecure-skip-tls-verify --request-timeout=5s get tektoninstallersets.operator.tekton.dev -o json
queue ${ARTIFACT_DIR}/tektonpipelines.json  oc --insecure-skip-tls-verify --request-timeout=5s get tektonpipelines.operator.tekton.dev -o json
queue ${ARTIFACT_DIR}/tektontriggers.json  oc --insecure-skip-tls-verify --request-timeout=5s get tektontriggers.operator.tekton.dev -o json
queue ${ARTIFACT_DIR}/clustertasks.json  oc --insecure-skip-tls-verify --request-timeout=5s get clustertasks.tekton.dev -o json
queue ${ARTIFACT_DIR}/clusterinterceptors.json  oc --insecure-skip-tls-verify --request-timeout=5s get clusterinterceptors.triggers.tekton.dev -o json
queue ${ARTIFACT_DIR}/clustertriggerbindings.json  oc --insecure-skip-tls-verify --request-timeout=5s get clustertriggerbindings.triggers.tekton.dev -o json
queue ${ARTIFACT_DIR}/clusterregistrars.json  oc --insecure-skip-tls-verify --request-timeout=5s get clusterregistrars.singapore.open-cluster-management.io -o json
queue ${ARTIFACT_DIR}/gitopsservices.json  oc --insecure-skip-tls-verify --request-timeout=5s get gitopsservices.pipelines.openshift.io -o json

# Must gather steps to collect OpenShift logs
FILTER=gzip queue ${ARTIFACT_DIR}/openapi.json.gz oc --insecure-skip-tls-verify --request-timeout=5s get --raw /openapi/v2

while IFS= read -r i; do
  file="$( echo "$i" | cut -d ' ' -f 2,3,5 | tr -s ' ' '_' )"
  FILTER=gzip queue ${ARTIFACT_DIR}/pods/${file}.log.gz oc --insecure-skip-tls-verify logs --request-timeout=20s $i
  FILTER=gzip queue ${ARTIFACT_DIR}/pods/${file}_previous.log.gz oc --insecure-skip-tls-verify logs --request-timeout=20s -p $i
done < /tmp/containers
