#!/bin/bash

# Build script for Claude Code Docker images
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
IMAGE_TAG="latest"
BUILD_TYPE="all"

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -t, --tag TAG        Image tag (default: latest)"
    echo "  -b, --build TYPE     Build type: base, python, or all (default: all)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                           # Build all images with 'latest' tag"
    echo "  $0 -t v1.0.0                # Build all images with 'v1.0.0' tag"
    echo "  $0 -b python -t dev          # Build only python image with 'dev' tag"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -b|--build)
            BUILD_TYPE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Function to build an image
build_image() {
    local context=$1
    local dockerfile=$2
    local image_name=$3
    local tag=$4
    
    echo -e "${YELLOW}Building $image_name:$tag...${NC}"
    docker build -f "$dockerfile" -t "$image_name:$tag" "$context"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Successfully built $image_name:$tag${NC}"
    else
        echo -e "${RED}✗ Failed to build $image_name:$tag${NC}"
        exit 1
    fi
}

# Main build logic
echo -e "${YELLOW}Starting Claude Code Docker builds...${NC}"

case $BUILD_TYPE in
    "base")
        build_image "containers" "containers/Dockerfile" "claude-code-base" "$IMAGE_TAG"
        ;;
    "python")
        # Build base first if it doesn't exist
        if [ -z "$(docker images -q claude-code-base:$IMAGE_TAG 2> /dev/null)" ]; then
            echo -e "${YELLOW}Base image not found, building it first...${NC}"
            build_image "containers" "containers/Dockerfile" "claude-code-base" "$IMAGE_TAG"
        fi
        build_image "containers/python" "containers/python/Dockerfile" "claude-code-python" "$IMAGE_TAG"
        ;;
    "all")
        build_image "containers" "containers/Dockerfile" "claude-code-base" "$IMAGE_TAG"
        build_image "containers/python" "containers/python/Dockerfile" "claude-code-python" "$IMAGE_TAG"
        ;;
    *)
        echo -e "${RED}Error: Invalid build type '$BUILD_TYPE'. Use 'base', 'python', or 'all'.${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}✓ All builds completed successfully!${NC}"

# Display built images
echo -e "\n${YELLOW}Built images:${NC}"
case $BUILD_TYPE in
    "base")
        docker images claude-code-base:$IMAGE_TAG
        ;;
    "python")
        docker images claude-code-python:$IMAGE_TAG
        ;;
    "all")
        docker images | grep -E "claude-code-(base|python)" | grep $IMAGE_TAG
        ;;
esac