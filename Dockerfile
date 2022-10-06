ARG BUILDPLATFORM="linux/amd64"
ARG BUILDERIMAGE="golang:1.19-bullseye"
ARG BASEIMAGE="gcr.io/distroless/static:nonroot"

FROM --platform=${BUILDPLATFORM} ${BUILDERIMAGE} as builder

ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT=""
ARG LDFLAGS

ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOOS=${TARGETOS} \
    GOARCH=${TARGETARCH} \
    GOARM=${TARGETVARIANT}

WORKDIR /go/src/github.com/open-policy-agent/gatekeeper-external-data-provider

COPY . .

RUN make build

FROM ${BASEIMAGE}

WORKDIR /

COPY --from=builder /go/src/github.com/open-policy-agent/gatekeeper-external-data-provider/bin/provider .

COPY --from=builder --chown=65532:65532 /go/src/github.com/open-policy-agent/gatekeeper-external-data-provider/certs/tls.crt \
    /go/src/github.com/open-policy-agent/gatekeeper-external-data-provider/certs/tls.key \
    /certs/

USER 65532:65532

ENTRYPOINT ["/provider"]
