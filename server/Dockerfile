# Build stage
FROM golang:1.24-alpine AS builder

# Install git dan ca-certificates (diperlukan untuk SSL)
RUN apk add --no-cache git ca-certificates tzdata

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o workradar-server ./cmd/main.go

# Final stage
FROM alpine:latest

# Install ca-certificates untuk SSL connections
RUN apk --no-cache add ca-certificates tzdata

# Set timezone
ENV TZ=Asia/Jakarta

WORKDIR /root/

# Copy binary dari builder
COPY --from=builder /app/workradar-server .

# Copy firebase config (jika ada)
COPY --from=builder /app/workradar-firebase.json* ./

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/api/health || exit 1

# Run binary
CMD ["./workradar-server"]
