#!/bin/bash

# Build script for the Claude Code Docker image
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
IMAGE_TAG="latest"
IMAGE_NAME="claude-code-base" # This is now the only image

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -t, --tag TAG        Image tag (default: latest)"
    echo "  -n, --name NAME      Image name (default: claude-code-base)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                           # Build claude-code-base:latest"
    echo "  $0 -t v1.0.0                # Build claude-code-base:v1.0.0"
    echo "  $0 -n my-claude-app -t dev   # Build my-claude-app:dev"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -n|--name)
            IMAGE_NAME="$2"
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
# Usage: build_image <context_path> <dockerfile_path> <image_name_to_build> <image_tag_to_build>
build_image() {
    local context=$1
    local dockerfile=$2
    local image_name_to_build=$3
    local image_tag_to_build=$4

    echo -e "${YELLOW}Building $image_name_to_build:$image_tag_to_build...${NC}"
    
    # The Dockerfile now builds from ubuntu:24.04, so no specific project base image to pull here.
    # Docker will pull ubuntu:24.04 if not present locally.

    sudo docker build -f "$dockerfile" -t "$image_name_to_build:$image_tag_to_build" "$context"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Successfully built $image_name_to_build:$image_tag_to_build${NC}"
    else
        echo -e "${RED}✗ Failed to build $image_name_to_build:$image_tag_to_build${NC}"
        exit 1
    fi
}

# Main build logic
echo -e "${YELLOW}Starting Claude Code Docker build (Image: $IMAGE_NAME, Tag: $IMAGE_TAG)...${NC}"

build_image "containers" "containers/Dockerfile" "$IMAGE_NAME" "$IMAGE_TAG"

echo -e "${GREEN}✓ Build completed successfully!${NC}"

# Display built image
echo -e "\n${YELLOW}Built image:${NC}"
docker images "$IMAGE_NAME:$IMAGE_TAG"