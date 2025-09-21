# Simple Makefile for Package-Updates-Noty (Go)

BINARY := update-noti
PACKAGE := github.com/raf181/Package-Updates-Noty
CMD := ./cmd/update-noti

.PHONY: build clean test

build:
	GOFLAGS="-trimpath" CGO_ENABLED=0 go build -ldflags "-s -w -X main.Version=$$(git describe --tags --always 2>/dev/null || echo dev)" -o $(BINARY) $(CMD)

clean:
	rm -f $(BINARY)

linux-amd64:
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags "-s -w -X main.Version=$$(git describe --tags --always 2>/dev/null || echo dev)" -o $(BINARY)_linux_amd64 $(CMD)

linux-arm64:
	GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -ldflags "-s -w -X main.Version=$$(git describe --tags --always 2>/dev/null || echo dev)" -o $(BINARY)_linux_arm64 $(CMD)

release: linux-amd64 linux-arm64

