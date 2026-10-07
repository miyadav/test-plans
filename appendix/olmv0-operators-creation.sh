#!/usr/bin/env bash
#
# install-operator-olmv0.sh
#
# Install an operator through classic OLMv0 (Subscription + OperatorGroup),
# bypassing OLMv1 / "Software Catalog" (ClusterExtension) on OCP 5.0+ clusters.
#
# Usage:
#   ./install-operator-olmv0.sh <package-or-search> [-n <namespace>] [-c <channel>] [--approval Manual|Automatic] [--dry-run]
#
# Examples:
#   ./install-operator-olmv0.sh awss3-operator-registry -n aws-s3
#   ./install-operator-olmv0.sh "AWS S3"                 # searches, lists matches
#   ./install-operator-olmv0.sh aws-load-balancer-operator -n aws-load-balancer-operator -c stable-v1
#
set -euo pipefail

MARKETPLACE_NS="openshift-marketplace"
APPROVAL="Automatic"
DRY_RUN=false
NAMESPACE=""
CHANNEL=""
PKG=""

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo ">> $*" >&2; }

# ---- parse args ----
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace) NAMESPACE="$2"; shift 2 ;;
    -c|--channel)   CHANNEL="$2";   shift 2 ;;
    --approval)     APPROVAL="$2";  shift 2 ;;
    --dry-run)      DRY_RUN=true;   shift ;;
    -h|--help)      grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)             die "unknown flag: $1" ;;
    *)              PKG="$1";       shift ;;
  esac
done

[[ -n "$PKG" ]] || die "give an operator package name or search term (see --help)"
command -v oc >/dev/null || die "oc not found in PATH"
oc whoami >/dev/null 2>&1 || die "not logged in / KUBECONFIG not set (try: export KUBECONFIG=~/.kube/config)"

# ---- resolve package ----
if ! oc get packagemanifest "$PKG" -n "$MARKETPLACE_NS" >/dev/null 2>&1; then
  info "No exact package '$PKG' — searching display names and package names..."
  MATCHES=$(oc get packagemanifests -n "$MARKETPLACE_NS" \
    -o custom-columns='PKG:.metadata.name,DISPLAY:.status.channels[0].currentCSVDesc.displayName,CATALOG:.status.catalogSource' \
    --no-headers 2>/dev/null | grep -iE "$PKG" || true)
  [[ -n "$MATCHES" ]] || die "no package or display name matching '$PKG'"
  echo "Matches found — re-run with the exact PKG (first column):" >&2
  printf '%s\n' "$MATCHES" | sed 's/^/    /' >&2
  exit 2
fi

# ---- read package metadata ----
CATALOG=$(oc get packagemanifest "$PKG" -n "$MARKETPLACE_NS" -o jsonpath='{.status.catalogSource}')
CATALOG_NS=$(oc get packagemanifest "$PKG" -n "$MARKETPLACE_NS" -o jsonpath='{.status.catalogSourceNamespace}')
DISPLAY=$(oc get packagemanifest "$PKG" -n "$MARKETPLACE_NS" -o jsonpath='{.status.channels[0].currentCSVDesc.displayName}')
[[ -n "$CHANNEL" ]] || CHANNEL=$(oc get packagemanifest "$PKG" -n "$MARKETPLACE_NS" -o jsonpath='{.status.defaultChannel}')

# install modes for the chosen channel
MODES=$(oc get packagemanifest "$PKG" -n "$MARKETPLACE_NS" \
  -o jsonpath="{range .status.channels[?(@.name=='$CHANNEL')].currentCSVDesc.installModes[*]}{.type}={.supported} {end}")
[[ -n "$MODES" ]] || die "channel '$CHANNEL' not found for package '$PKG'"
supports() { echo "$MODES" | grep -q "$1=true"; }

# ---- choose namespace + operatorgroup scope ----
NEED_OG=true
OG_SPEC=""
if supports AllNamespaces; then
  # global operator -> prefer the cluster-wide openshift-operators (already has a global OG)
  [[ -n "$NAMESPACE" ]] || NAMESPACE="openshift-operators"
  if [[ "$NAMESPACE" == "openshift-operators" ]]; then
    NEED_OG=false   # a global OperatorGroup already exists there
  else
    OG_SPEC="spec: {}"   # global OG (watches all namespaces)
  fi
else
  # namespace-scoped operator -> must have a dedicated namespace + targeted OG
  [[ -n "$NAMESPACE" ]] || NAMESPACE="$PKG"
  OG_SPEC=$'spec:\n  targetNamespaces:\n    - '"$NAMESPACE"
fi

# ---- build manifest ----
MANIFEST="apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
"
if [[ "$NEED_OG" == true ]]; then
  MANIFEST+="---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: ${NAMESPACE}-og
  namespace: $NAMESPACE
$OG_SPEC
"
fi
MANIFEST+="---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: $PKG
  namespace: $NAMESPACE
spec:
  channel: $CHANNEL
  name: $PKG
  source: $CATALOG
  sourceNamespace: ${CATALOG_NS:-$MARKETPLACE_NS}
  installPlanApproval: $APPROVAL
"

info "Package : $PKG  (${DISPLAY:-n/a})"
info "Catalog : $CATALOG / ${CATALOG_NS:-$MARKETPLACE_NS}"
info "Channel : $CHANNEL"
info "Namespace: $NAMESPACE   (install modes: $MODES)"

if [[ "$DRY_RUN" == true ]]; then
  echo "$MANIFEST"
  exit 0
fi

echo "$MANIFEST" | oc apply -f -

# ---- verify it went through OLMv0, not OLMv1 ----
info "Waiting for CSV to appear/succeed (up to 5 min)..."
if oc wait --for=jsonpath='{.status.phase}'=Succeeded csv -l operators.coreos.com/"$PKG"."$NAMESPACE"= \
     -n "$NAMESPACE" --timeout=300s 2>/dev/null; then
  info "CSV reached Succeeded."
else
  info "CSV not Succeeded yet — current state:"
  oc get subscription "$PKG" -n "$NAMESPACE" -o jsonpath='{.status.state}{"\n"}' >&2 || true
fi

echo
echo "=== OLMv0 objects in $NAMESPACE ==="
oc get subscription,installplan,csv -n "$NAMESPACE"
echo
echo "=== OLMv1 ClusterExtensions (MUST be empty for this operator) ==="
if oc get crd clusterextensions.olm.operatorframework.io >/dev/null 2>&1; then
  oc get clusterextensions.olm.operatorframework.io
else
  echo "(OLMv1 can be directly installed from GUI on this cluster)"
fi

