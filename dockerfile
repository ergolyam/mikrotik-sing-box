FROM --platform=$BUILDPLATFORM docker.io/golang:1.24-alpine AS builder

LABEL maintainer="grisha765 <grisha765@tuta.io>"

WORKDIR /go/src/github.com/sagernet/sing-box

ARG TARGETOS TARGETARCH

ARG GOPROXY=""

ENV VERSION="1.11.6"

ENV GOPROXY ${GOPROXY}

ENV CGO_ENABLED=0

ENV GOOS=$TARGETOS

ENV GOARCH=$TARGETARCH

RUN set -ex \
    && apk add git build-base \
    && git clone https://github.com/SagerNet/sing-box.git -b "v$VERSION" /go/src/github.com/sagernet/sing-box \
    && export COMMIT=$(git rev-parse --short HEAD) \
    && go build -v -trimpath -tags \
        "with_utls" \
        -o /go/bin/sing-box \
        -ldflags "-X \"github.com/sagernet/sing-box/constant.Version=$VERSION\" -s -w -buildid=" \
        ./cmd/sing-box


FROM --platform=$TARGETPLATFORM docker.io/busybox:stable-musl AS main

LABEL maintainer="grisha765 <grisha765@tuta.io>"

RUN mkdir -p /etc/sing-box

COPY --from=builder /go/bin/sing-box /usr/local/bin/sing-box

COPY ./entrypoint.sh /usr/bin/entrypoint.sh

ENTRYPOINT ["/usr/bin/entrypoint.sh"]

