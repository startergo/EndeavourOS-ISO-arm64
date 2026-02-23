#!/usr/bin/env bash
set -euo pipefail

# Docker build wrapper for EndeavourOS aarch64 ISO

IMAGE_NAME="endeavouros-aarch64-builder"
CONTAINER_NAME="endeavouros-iso-builder"

case "${1:-build}" in
  build)
    echo "Building Docker image (no cache)..."
    docker build --no-cache -t "$IMAGE_NAME" .
    ;;

  build-cache)
    echo "Building Docker image (with cache)..."
    docker build -t "$IMAGE_NAME" .
    ;;

  prepare)
    echo "Running prepare.sh in container..."
    docker run --rm -it --privileged \
      -v "$(pwd):/workspace" \
      -w /workspace \
      "$IMAGE_NAME" \
      bash prepare.sh
    ;;

  iso)
    echo "Building ISO in container..."
    mkdir -p "$(pwd)/out"
    docker run --rm -it --privileged \
      -v "$(pwd):/workspace" \
      -v "$(pwd)/out:/out" \
      -w /workspace \
      "$IMAGE_NAME" \
      bash -c "mkdir -p /build/work /build/out && MKARCHISO_WORK_DIR=/build/work bash mkarchiso -v -w /build/work -o /build/out . && cp /build/out/*.iso /out/"
    ;;

  all)
    echo "Running full build (prepare + mkarchiso)..."
    mkdir -p "$(pwd)/out"
    docker run --rm -it --privileged \
      -v "$(pwd):/workspace" \
      -v "$(pwd)/out:/out" \
      -w /workspace \
      "$IMAGE_NAME" \
      bash -c "mkdir -p /build/work /build/out && bash prepare.sh && MKARCHISO_WORK_DIR=/build/work bash mkarchiso -v -w /build/work -o /build/out . && cp /build/out/*.iso /out/"
    ;;

  shell)
    echo "Starting shell in container..."
    mkdir -p "$(pwd)/out"
    docker run --rm -it --privileged \
      -v "$(pwd):/workspace" \
      -v "$(pwd)/out:/out" \
      -w /workspace \
      "$IMAGE_NAME" \
      bash
    ;;

  clean)
    echo "Cleaning build artifacts..."
    docker run --rm -it --privileged \
      -v "$(pwd):/workspace" \
      -w /workspace \
      "$IMAGE_NAME" \
      bash reset.sh
    ;;

  push-ghcr)
    GHCR_IMAGE="ghcr.io/${GHCR_USER:-startergo}/endeavouros-aarch64-builder"
    GHCR_ISO="ghcr.io/${GHCR_USER:-startergo}/endeavouros-iso-arm64"
    TAG="${2:-latest}"

    echo "Tagging and pushing Docker builder image to ghcr.io..."
    docker tag "$IMAGE_NAME" "${GHCR_IMAGE}:${TAG}"
    docker tag "$IMAGE_NAME" "${GHCR_IMAGE}:latest"
    docker push "${GHCR_IMAGE}:${TAG}"
    docker push "${GHCR_IMAGE}:latest"
    echo "Builder image pushed: ${GHCR_IMAGE}:${TAG}"

    ISO_FILE="$(ls -1 "$(pwd)/out/"*.iso 2>/dev/null | head -n1)"
    if [[ -z "$ISO_FILE" ]]; then
      echo "No ISO found in out/ — run './docker-build.sh all' first"
      exit 1
    fi
    echo "Pushing ISO as OCI artifact to ghcr.io..."
    if ! command -v oras &>/dev/null; then
      echo "oras not found — install from https://oras.land/docs/installation"
      exit 1
    fi
    ISO_DIR="$(dirname "$ISO_FILE")"
    ISO_NAME="$(basename "$ISO_FILE")"
    (cd "$ISO_DIR" && \
      oras push "${GHCR_ISO}:${TAG}" \
        --artifact-type application/vnd.endeavouros.iso \
        "${ISO_NAME}:application/octet-stream" && \
      oras push "${GHCR_ISO}:latest" \
        --artifact-type application/vnd.endeavouros.iso \
        "${ISO_NAME}:application/octet-stream"
    )
    echo "ISO pushed: ${GHCR_ISO}:${TAG}"
    echo "Pull with: oras pull ${GHCR_ISO}:${TAG}"
    ;;

  push-dockerhub)
    DOCKERHUB_IMAGE="docker.io/${DOCKERHUB_USER:-startergo}/endeavouros-aarch64-builder"
    TAG="${2:-latest}"

    echo "Tagging and pushing Docker builder image to Docker Hub..."
    docker tag "$IMAGE_NAME" "${DOCKERHUB_IMAGE}:${TAG}"
    docker tag "$IMAGE_NAME" "${DOCKERHUB_IMAGE}:latest"
    docker push "${DOCKERHUB_IMAGE}:${TAG}"
    docker push "${DOCKERHUB_IMAGE}:latest"
    echo "Builder image pushed: ${DOCKERHUB_IMAGE}:${TAG}"
    ;;

  push)
    TAG="${2:-latest}"
    "$0" push-ghcr "$TAG"
    "$0" push-dockerhub "$TAG"
    ;;

  *)
    echo "Usage: $0 {build|build-cache|prepare|iso|all|push|push-ghcr|push-dockerhub|shell|clean}"
    echo ""
    echo "Commands:"
    echo "  build                - Build Docker image (no cache)"
    echo "  build-cache          - Build Docker image (with cache, faster)"
    echo "  prepare              - Run prepare.sh (download wallpapers, build skel)"
    echo "  iso                  - Build ISO only"
    echo "  all                  - Full build (prepare + iso)"
    echo "  push [tag]           - Push builder image + ISO to both ghcr.io and Docker Hub"
    echo "  push-ghcr [tag]      - Push builder image + ISO to ghcr.io only"
    echo "  push-dockerhub [tag] - Push builder image to Docker Hub only"
    echo "  shell                - Start interactive shell in container"
    echo "  clean                - Clean build cache (run reset.sh)"
    exit 1
    ;;
esac
