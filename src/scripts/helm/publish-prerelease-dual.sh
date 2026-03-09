#!/bin/bash
set -euo pipefail

echo "BETA_VERSION: ${BETA_VERSION:?}"
echo "AWS_REGION: ${AWS_REGION:?}"

ECR_REPOSITORY_URI=${ECR_REPOSITORY_URI:-"168387678261.dkr.ecr.us-east-1.amazonaws.com"}
echo "ECR_REPOSITORY_URI: ${ECR_REPOSITORY_URI}"

export HELM_EXPERIMENTAL_OCI=1

LOG_DIR="/tmp/helm-publish-logs"
mkdir -p "$LOG_DIR"

MAX_PARALLEL=2

# Login to ECR once upfront
aws ecr get-login-password --region "$AWS_REGION" | \
  helm registry login --username AWS --password-stdin "$ECR_REPOSITORY_URI"

# Discover charts
CHARTS=()
for file in *; do
  if [[ -d "$file" && -f "$file/$file/Chart.yaml" ]]; then
    CHARTS+=("$file")
  fi
done

if [ ${#CHARTS[@]} -eq 0 ]; then
  echo "No charts found"
  exit 0
fi

echo "Found ${#CHARTS[@]} charts: ${CHARTS[*]}"

# ── Phase 1: Package charts in parallel (max $MAX_PARALLEL at a time) ──
cat > /tmp/package-chart.sh <<HELPER
#!/bin/bash
file="\$1"
if ! (
  set -euo pipefail
  cd "\$file"
  helm dep update "\$file"
  helm package "\$file" --version "$BETA_VERSION"
  CHART="\$file-${BETA_VERSION}.tgz"
  if [ ! -f "\$CHART" ]; then
    echo "ERROR: Packaged chart does not have expected name \$CHART"
    exit 3
  fi
) > "$LOG_DIR/\$file-package.log" 2>&1; then
  echo "FAILED: packaging \$file"
  cat "$LOG_DIR/\$file-package.log"
  exit 1
fi
echo "Packaged \$file"
HELPER
chmod +x /tmp/package-chart.sh

printf '%s\0' "${CHARTS[@]}" | xargs -0 -n1 -P"$MAX_PARALLEL" /tmp/package-chart.sh

echo "All ${#CHARTS[@]} charts packaged, starting pushes..."

# ── Phase 2: Push to S3 (sequential) and ECR (parallel, max $MAX_PARALLEL) ──
cat > /tmp/push-ecr.sh <<HELPER
#!/bin/bash
file="\$1"
CHART="\$file/\$file-${BETA_VERSION}.tgz"
if ! helm push "\$CHART" "oci://${ECR_REPOSITORY_URI}/voiceflow-charts-beta" \
    > "$LOG_DIR/\$file-push-ecr.log" 2>&1; then
  echo "FAILED: ECR push for \$file"
  cat "$LOG_DIR/\$file-push-ecr.log"
  exit 1
fi
echo "Pushed \$file to ECR"
HELPER
chmod +x /tmp/push-ecr.sh

# Start ECR pushes in background (parallel, limited to $MAX_PARALLEL)
printf '%s\0' "${CHARTS[@]}" | xargs -0 -n1 -P"$MAX_PARALLEL" /tmp/push-ecr.sh &
ECR_PID=$!

# Push to S3 sequentially in foreground (protects shared bucket index)
S3_FAILED=0
for file in "${CHARTS[@]}"; do
  CHART="$file/$file-${BETA_VERSION}.tgz"
  echo "Pushing $file to S3..."
  if ! helm s3 push --force "$CHART" voiceflow-charts-s3-beta \
      > "$LOG_DIR/$file-push-s3.log" 2>&1; then
    echo "FAILED: S3 push for $file"
    cat "$LOG_DIR/$file-push-s3.log"
    S3_FAILED=1
  else
    echo "Pushed $file to S3"
  fi
done

# Wait for ECR pushes to finish
ECR_FAILED=0
if ! wait "$ECR_PID"; then
  ECR_FAILED=1
fi

if [ "$S3_FAILED" -ne 0 ] || [ "$ECR_FAILED" -ne 0 ]; then
  echo "One or more pushes failed. See logs in $LOG_DIR"
  exit 1
fi

echo "All charts published to S3 and ECR"
