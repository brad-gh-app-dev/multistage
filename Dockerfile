# syntax=docker/dockerfile:1

# ---- Stage 1: build ----------------------------------------------------------
FROM golang:1.23-alpine AS build

WORKDIR /src

# Dependencies first so this layer caches across source-only changes.
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY . .

# Static binary: no cgo, symbols and DWARF stripped.
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
FROM gcr.io/distroless/static-debian12:nonroot AS runtime

WORKDIR /
COPY --from=build /out/app /app

USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app"]
