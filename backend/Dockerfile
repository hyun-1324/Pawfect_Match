FROM golang:1.22.5 AS builder

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod tidy

COPY . .

RUN go build -o main ./cmd/myapp

EXPOSE 8080

FROM alpine:latest
WORKDIR /app
RUN apk add --no-cache libc6-compat

ARG USER=webapp
RUN adduser -D $USER
USER ${USER}

COPY --from=builder /app/main .

CMD ["./main"]