ARG BCI_IMAGE=registry.suse.com/bci/bci-base:latest
ARG GO_IMAGE=rancher/hardened-build-base:v1.16.10b7
FROM ${BCI_IMAGE} as bci
FROM ${GO_IMAGE} as builder
ENV CC=/usr/local/musl/bin/musl-gcc
# setup the build
ARG PKG="github.com/kubernetes-incubator/metrics-server"
ARG SRC="github.com/kubernetes-sigs/metrics-server"
ARG TAG="v0.5.2"
ARG ARCH="amd64"
RUN git clone --depth=1 https://${SRC}.git $GOPATH/src/${PKG}
WORKDIR $GOPATH/src/${PKG}
RUN git fetch --all --tags --prune
RUN git checkout tags/${TAG} -b ${TAG}
RUN if echo ${TAG} | grep -qE '^v0\.3\.'; then \
    GO111MODULE=off \
    go run vendor/k8s.io/kube-openapi/cmd/openapi-gen/openapi-gen.go --logtostderr \
    -i k8s.io/metrics/pkg/apis/metrics/v1beta1,k8s.io/apimachinery/pkg/apis/meta/v1,k8s.io/apimachinery/pkg/api/resource,k8s.io/apimachinery/pkg/version \
    -p ${PKG}/pkg/generated/openapi/ \
    -O zz_generated.openapi \
    -h $(pwd)/hack/boilerplate.go.txt \
    -r /dev/null; \
    else \
    go install -mod=readonly k8s.io/kube-openapi/cmd/openapi-gen && \
    ${GOPATH}/bin/openapi-gen --logtostderr \
    -i k8s.io/metrics/pkg/apis/metrics/v1beta1,k8s.io/apimachinery/pkg/apis/meta/v1,k8s.io/apimachinery/pkg/api/resource,k8s.io/apimachinery/pkg/version \
    -p ${PKG}/pkg/generated/openapi/ \
    -O zz_generated.openapi \
    -h $(pwd)/scripts/boilerplate.go.txt \
    -r /dev/null; \
    fi
RUN GO111MODULE=$(if echo ${TAG} | grep -qE '^v0\.3\.'; then echo off; fi) \
    GO_LDFLAGS="-linkmode=external \
    -X ${PKG}/pkg/version.Version=${TAG} \
    -X ${PKG}/pkg/version.gitCommit=$(git rev-parse HEAD) \
    -X ${PKG}/pkg/version.gitTreeState=clean \
    " \
    go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -o bin/metrics-server ./cmd/metrics-server
RUN go-assert-static.sh bin/*
RUN if [ "${ARCH}" != "s390x" ]; then \
       go-assert-boring.sh bin/*; \
    fi
RUN install -s bin/* /usr/local/bin
RUN metrics-server --help

FROM bci
RUN zypper update -y && \
    zypper clean --all
COPY --from=builder /usr/local/bin/metrics-server /
ENTRYPOINT ["/metrics-server"]
