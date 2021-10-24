BUILDER ?= podman
IMAGE_REGISTRY ?= crunchydata
IMAGE_NAME ?= postgres-realtime-demo
IMAGE_TAG ?= latest

all: build

build:
	$(BUILDER) build -t $(IMAGE_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) .

push:
	$(BUILDER) push $(IMAGE_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
