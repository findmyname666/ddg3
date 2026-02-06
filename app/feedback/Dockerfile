# Multi-stage Dockerfile for FeedDuck feedback application
# Build context: app/feedback/
# Stage 1: Build the Go application
FROM golang:1.25-alpine AS builder

WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . ./

# Build the application
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a \
    -o /feedback \
    ./cmd/feedback

# Stage 2: Create minimal runtime image
FROM alpine:3.23

# Install runtime dependencies
# ca-certificates: Required for HTTPS/TLS connections (database, APIs)
# tzdata: Required for timezone operations in Go's time package
RUN apk add --no-cache ca-certificates tzdata

# Create non-root user
RUN addgroup -g 1000 feedback && \
    adduser -D -u 1000 -G feedback feedback

# Copy binary from builder
COPY --from=builder --chown=feedback:feedback /feedback /usr/local/bin/feedback

# Switch to non-root user
USER feedback

# Set working directory (creates /app automatically, owned by feedback)
WORKDIR /app

# Copy templates and static files (creates subdirectories automatically)
COPY --chown=feedback:feedback pkgs/web/templates ./templates
COPY --chown=feedback:feedback pkgs/web/static ./static

# Copy database migrations
COPY --chown=feedback:feedback db/migrations/ ./db/migrations/

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Run the application
ENTRYPOINT ["/usr/local/bin/feedback"]
CMD ["web", "--host=0.0.0.0", "--port=8080"]
