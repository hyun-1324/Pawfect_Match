# Stage 1: Build the frontend
FROM node:14 AS build-frontend
WORKDIR /app
COPY frontend/package*.json ./
RUN npm install
COPY frontend ./
RUN npm run build

# Stage 2: Build the backend
FROM golang:1.22.5 AS build-backend
WORKDIR /app
COPY backend/go.mod backend/go.sum ./
RUN go mod download
COPY backend ./
COPY --from=build-frontend /app/build /app/frontend/build
RUN go build -o ./main ./cmd/myapp

# Final stage: Create the runtime image
FROM alpine:3.20.2
WORKDIR /app
COPY --from=build-backend /app/main /app
COPY --from=build-frontend /app/build /app/frontend/build
EXPOSE 8080
# Needed for the Go binary to run on Alpine
RUN apk add --no-cache libc6-compat
CMD ["/app/main"]