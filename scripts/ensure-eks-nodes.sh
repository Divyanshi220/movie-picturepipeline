#!/usr/bin/env bash
# Ensure the Udacity EKS node group has at least one Ready worker.
# Safe to re-run. Uses AWS CLI + kubectl already configured in CD.
set -euo pipefail

CLUSTER="${CLUSTER_NAME:-cluster}"
NODEGROUP="${NODEGROUP_NAME:-udacity}"
REGION="${AWS_REGION:-us-east-1}"

ready_node_count() {
  kubectl get nodes --no-headers 2>/dev/null | awk '$2=="Ready"{c++} END{print c+0}'
}

echo "== Current nodes =="
kubectl get nodes -o wide || true
READY="$(ready_node_count)"
echo "Ready nodes: ${READY}"

if [ "${READY}" -gt 0 ]; then
  echo "Worker nodes already Ready — nothing to repair."
  exit 0
fi

echo "No Ready worker nodes. Attempting to repair node group ${NODEGROUP} on cluster ${CLUSTER}."

if ! aws eks describe-nodegroup --region "${REGION}" --cluster-name "${CLUSTER}" --nodegroup-name "${NODEGROUP}" >/tmp/ng.json 2>/dev/null; then
  echo "ERROR: node group ${NODEGROUP} not found on cluster ${CLUSTER}."
  aws eks list-nodegroups --region "${REGION}" --cluster-name "${CLUSTER}" || true
  exit 1
fi

echo "Scaling node group desiredSize=1 ..."
aws eks update-nodegroup-config \
  --region "${REGION}" \
  --cluster-name "${CLUSTER}" \
  --nodegroup-name "${NODEGROUP}" \
  --scaling-config minSize=1,maxSize=2,desiredSize=1 >/dev/null || true

for _ in $(seq 1 36); do
  READY="$(ready_node_count)"
  echo "Waiting for Ready nodes after scale (have ${READY})..."
  if [ "${READY}" -gt 0 ]; then
    kubectl get nodes -o wide
    exit 0
  fi
  sleep 10
done

echo "Scale did not bring nodes up. Recreating node group ${NODEGROUP}..."

ROLE="$(jq -r .nodegroup.nodeRole /tmp/ng.json)"
mapfile -t SUBNETS < <(jq -r '.nodegroup.subnets[]' /tmp/ng.json)
INSTANCE="$(jq -r '.nodegroup.instanceTypes[0] // "t3.small"' /tmp/ng.json)"
VERSION="$(jq -r '.nodegroup.version' /tmp/ng.json)"
AMI="$(jq -r '.nodegroup.amiType // "AL2023_x86_64_STANDARD"' /tmp/ng.json)"
CAPACITY="$(jq -r '.nodegroup.capacityType // "ON_DEMAND"' /tmp/ng.json)"
DISK="$(jq -r '.nodegroup.diskSize // 20' /tmp/ng.json)"

STATUS="$(jq -r .nodegroup.status /tmp/ng.json)"
if [ "${STATUS}" != "DELETING" ]; then
  aws eks delete-nodegroup \
    --region "${REGION}" \
    --cluster-name "${CLUSTER}" \
    --nodegroup-name "${NODEGROUP}" >/dev/null || true
fi

echo "Waiting for old node group deletion..."
aws eks wait nodegroup-deleted \
  --region "${REGION}" \
  --cluster-name "${CLUSTER}" \
  --nodegroup-name "${NODEGROUP}"

echo "Creating fresh node group..."
aws eks create-nodegroup \
  --region "${REGION}" \
  --cluster-name "${CLUSTER}" \
  --nodegroup-name "${NODEGROUP}" \
  --node-role "${ROLE}" \
  --subnets "${SUBNETS[@]}" \
  --instance-types "${INSTANCE}" \
  --ami-type "${AMI}" \
  --capacity-type "${CAPACITY}" \
  --disk-size "${DISK}" \
  --scaling-config minSize=1,maxSize=2,desiredSize=1 \
  --kubernetes-version "${VERSION}" >/dev/null

echo "Waiting for node group to become ACTIVE..."
aws eks wait nodegroup-active \
  --region "${REGION}" \
  --cluster-name "${CLUSTER}" \
  --nodegroup-name "${NODEGROUP}"

for _ in $(seq 1 72); do
  READY="$(ready_node_count)"
  echo "Waiting for Ready nodes after recreate (have ${READY})..."
  if [ "${READY}" -gt 0 ]; then
    kubectl get nodes -o wide
    echo "Node group repaired successfully."
    exit 0
  fi
  sleep 10
done

echo "ERROR: nodes still not Ready after recreate."
kubectl get nodes -o wide || true
aws eks describe-nodegroup --region "${REGION}" --cluster-name "${CLUSTER}" --nodegroup-name "${NODEGROUP}" || true
exit 1
