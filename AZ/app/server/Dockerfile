# build stage
ARG GO_VERSION=1.10.2
FROM golang:${GO_VERSION}-alpine AS build-stage
WORKDIR /tmp
COPY ./ /tmp
RUN go build -o getazmeta getazmeta.go

# production stage
FROM alpine:3.7
WORKDIR /root/
COPY --from=build-stage /tmp/getazmeta .
EXPOSE 80
ENTRYPOINT ["/root/getazmeta"]