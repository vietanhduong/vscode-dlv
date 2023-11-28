FROM golang:1.21 as golang

RUN go install github.com/go-delve/delve/cmd/dlv@latest

FROM debian:bookworm

COPY --from=golang /go/bin/dlv /bin

WORKDIR /bin

# This is a fallback debug option, in case you need to 
# debug inside the container.
CMD ["tail", "-f", "/dev/null"]
