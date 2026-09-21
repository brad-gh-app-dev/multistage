# syntax=docker/dockerfile:1

# Global ARGs: declared before the first FROM, so they are usable in FROM lines.
# They are NOT visible inside a stage unless re-declared after that stage's FROM.
ARG GO_VERSION=1.24
ARG ALPINE_VERSION=3.20
ARG BUILD_IMAGE=golang:${GO_VERSION}-alpine${ALPINE_VERSION}
ARG RUNTIME_IMAGE=gcr.io/distroless/static-debian11:nonroot

# ---- Stage 1: build ----------------------------------------------------------
FROM ${BUILD_IMAGE} AS build

# Re-declare to pull the global value into this stage's scope.
ARG GO_VERSION
RUN echo "building with go ${GO_VERSION}" && go version

WORKDIR /src

COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY . .

ARG TARGETOS=linux
ARG TARGETARCH=amd64
ARG VERSION=dev
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -trimpath -ldflags="-s -w -X main.version=${VERSION}" -o /out/app ./cmd/app

# ---- Stage 2: test (optional, `--target test`) -------------------------------
FROM build AS test
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go vet ./... && go test ./...

# ---- Stage 3: runtime --------------------------------------------------------
# A stage name also resolves here, so `--build-arg RUNTIME_IMAGE=build` yields a
# fat debug image without touching the Dockerfile.
FROM ${RUNTIME_IMAGE} AS runtime

ARG VERSION=dev
LABEL org.opencontainers.image.version="${VERSION}"

WORKDIR /
COPY --from=build /out/app /app

USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app"]
