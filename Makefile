export PATH := $(PATH):`go env GOPATH`/bin
export GO111MODULE=on
LDFLAGS := -s -w

# Image URL to use all building/pushing image targets
REPO ?= quanzhenglong.com/edge
TAG ?= v1.0
IMG_FRPC ?= ${REPO}/kube-tunnel-client:${TAG}
IMG_FRPS ?= ${REPO}/kube-tunnel-server:${TAG}


# Produce CRDs that work back to Kubernetes 1.11 (no version conversion)
CRD_OPTIONS ?= "crd:allowDangerousTypes=true"

all: env fmt build

build: kube-tunnel-server kube-tunnel-client

env:
	@go version

# compile assets into binary file
file:
	rm -rf ./assets/frps/static/*
	rm -rf ./assets/frpc/static/*
	cp -rf ./web/frps/dist/* ./assets/frps/static
	cp -rf ./web/frpc/dist/* ./assets/frpc/static

fmt:
	go fmt ./...

fmt-more:
	gofumpt -l -w .

gci:
	gci write -s standard -s default -s "prefix(github.com/imneov/kube-frp/)" ./

vet:
	go vet ./...

kube-tunnel-server:
	env CGO_ENABLED=0 go build -trimpath -ldflags "$(LDFLAGS)" -tags frps -o bin/kube-tunnel-server ./cmd/frps

kube-tunnel-client:
	env CGO_ENABLED=0 go build -trimpath -ldflags "$(LDFLAGS)" -tags frpc -o bin/kube-tunnel-client ./cmd/frpc

test: gotest

gotest:
	go test -v --cover ./assets/...
	go test -v --cover ./cmd/...
	go test -v --cover ./client/...
	go test -v --cover ./server/...
	go test -v --cover ./pkg/...

e2e:
	./hack/run-e2e.sh

e2e-trace:
	DEBUG=true LOG_LEVEL=trace ./hack/run-e2e.sh

e2e-compatibility-last-frpc:
	if [ ! -d "./lastversion" ]; then \
		TARGET_DIRNAME=lastversion ./hack/download.sh; \
	fi
	FRPC_PATH="`pwd`/lastversion/frpc" ./hack/run-e2e.sh
	rm -r ./lastversion

e2e-compatibility-last-frps:
	if [ ! -d "./lastversion" ]; then \
		TARGET_DIRNAME=lastversion ./hack/download.sh; \
	fi
	FRPS_PATH="`pwd`/lastversion/frps" ./hack/run-e2e.sh
	rm -r ./lastversion

alltest: vet gotest e2e

# CRD related commands
manifests: controller-gen
	$(CONTROLLER_GEN) $(CRD_OPTIONS) rbac:roleName=manager-role webhook paths="./..." output:crd:artifacts:config=deploy/crd/bases

# Install CRDs into a cluster
install: manifests
	kubectl kustomize deploy/crd | kubectl apply -f -

# Uninstall CRDs from a cluster
uninstall:
	kubectl kustomize deploy/crd | kubectl delete -f -

# Generate code
generate: controller-gen
	$(CONTROLLER_GEN) object:headerFile="hack/boilerplate.go.txt" paths="./..."

# Build the docker image
docker-build: test
	docker build -t ${IMG_FRPC} .
	docker build -t ${IMG_FRPS} .

# Push the docker image
docker-push: 
	docker push ${IMG_FRPC}
	docker push ${IMG_FRPS}

clean:
	rm -f ./bin/kube-tunnel-client
	rm -f ./bin/kube-tunnel-server
	rm -rf ./lastversion

build-local-kube-tunnel-server: ; $(info $(M)...Begin to build frp binaries.)  @ ## Build frp binaries.
	CGO_ENABLED=0 go build -trimpath -ldflags "$(LDFLAGS)" -tags frps -o bin/kube-tunnel-server ./cmd/frps

build-kube-tunnel-client-image: ; $(info $(M)...Begin to build frp image.)  @ ## Build frp image.
	docker build -t ${IMG_FRPC}  -f dockerfiles/Dockerfile-for-kube-tunnel-client .

build-cross-kube-tunnel-client-image: ; $(info $(M)...Begin to build frp cross-platform image.)  @ ## Build frp cross-platform image.
	docker buildx build -t ${IMG_FRPC} --push --platform linux/amd64,linux/arm64  -f dockerfiles/Dockerfile-for-kube-tunnel-client .

build-local-kube-tunnel-client: ; $(info $(M)...Begin to build frp binaries.)  @ ## Build frp binaries.
	CGO_ENABLED=0 go build -trimpath -ldflags "$(LDFLAGS)" -tags frpc -o bin/kube-tunnel-client ./cmd/frpc

build-kube-tunnel-server-image: ; $(info $(M)...Begin to build frp image.)  @ ## Build frp image.
	docker build -t ${IMG_FRPS}  -f dockerfiles/Dockerfile-for-kube-tunnel-server .

build-cross-kube-tunnel-server-image: ; $(info $(M)...Begin to build frp cross-platform image.)  @ ## Build frp cross-platform image.
	docker buildx build -t ${IMG_FRPS} --push --platform linux/amd64,linux/arm64  -f dockerfiles/Dockerfile-for-kube-tunnel-server .

##@ Dependencies

# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

## Location to install dependencies to
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

## Tool Binaries
KUBECTL ?= kubectl
KUSTOMIZE ?= $(LOCALBIN)/kustomize-$(KUSTOMIZE_VERSION)
CONTROLLER_GEN ?= $(LOCALBIN)/controller-gen-$(CONTROLLER_TOOLS_VERSION)

## Tool Versions
KUSTOMIZE_VERSION ?= v5.3.0
CONTROLLER_TOOLS_VERSION ?= v0.14.0

.PHONY: controller-gen
controller-gen: $(CONTROLLER_GEN) ## Download controller-gen locally if necessary.
$(CONTROLLER_GEN): $(LOCALBIN)
	$(call go-install-tool,$(CONTROLLER_GEN),sigs.k8s.io/controller-tools/cmd/controller-gen,$(CONTROLLER_TOOLS_VERSION))

# go-install-tool will 'go install' any package with custom target and name of binary, if it doesn't exist
# $1 - target path with name of binary (ideally with version)
# $2 - package url which can be installed
# $3 - specific version of package
define go-install-tool
@[ -f $(1) ] || { \
set -e; \
package=$(2)@$(3) ;\
echo "Downloading $${package}" ;\
GOBIN=$(LOCALBIN) go install $${package} ;\
mv "$$(echo "$(1)" | sed "s/-$(3)$$//")" $(1) ;\
}
endef
