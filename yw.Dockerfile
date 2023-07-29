# Cross-compiling using Docker multi-platform builds/images and `xx`.
#
# https://docs.docker.com/build/building/multi-platform/
# https://github.com/tonistiigi/xx
FROM --platform=${BUILDPLATFORM:-linux/amd64} tonistiigi/xx AS xx

FROM --platform=${BUILDPLATFORM:-linux/amd64} golang:bookworm AS builder
WORKDIR /src

COPY --from=xx / /

# `ARG`/`ENV` pair is a workaround for `docker build` backward-compatibility.
#
# https://github.com/docker/buildx/issues/510
ARG BUILDPLATFORM
ENV BUILDPLATFORM=${BUILDPLATFORM:-linux/amd64}
RUN case "$BUILDPLATFORM" in \
        */amd64 ) PLATFORM=x86_64 ;; \
        */arm64 | */arm64/* ) PLATFORM=aarch64 ;; \
        * ) echo "Unexpected BUILDPLATFORM '$BUILDPLATFORM'" >&2; exit 1 ;; \
    esac;

# `ARG`/`ENV` pair is a workaround for `docker build` backward-compatibility.
#
# https://github.com/docker/buildx/issues/510
ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}

COPY . .
RUN mkdir -p ./dist \
    && CGO_ENABLED=0 xx-go build -o ./dist/traefik ./cmd/traefik \
    && xx-verify --static ./dist/traefik

FROM debian:bookworm-slim AS runtime

RUN apt-get update \
    && apt-get install -y ca-certificates tzdata curl \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/dist/traefik /usr/local/bin/
COPY --from=builder /src/entrypoint.sh /

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
CMD ["traefik"]