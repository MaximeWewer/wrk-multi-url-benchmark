### Step 1: Build wrk ###
FROM alpine:3.20 AS builder

# Install the necessary dependencies for compilation
RUN apk add --no-cache \
    build-base \
    openssl-dev \
    perl \
    linux-headers \
    git

# Download and build wrk
WORKDIR /tmp
RUN git clone https://github.com/wg/wrk.git && \
    cd wrk && \
    git checkout 4.2.0 && \
    make

### Step 2: Minimal image with wrk ###
FROM alpine:3.20

# Install runtime dependencies
RUN apk add --no-cache libgcc

# Create a volume to load Lua scripts
VOLUME /data

# Set the default working directory
WORKDIR /data

# Add a non-root user with a specific UID (1000) and a group with a specific GID (1000)
RUN addgroup -g 1000 -S wrkgroup && adduser -u 1000 -S wrkuser -G wrkgroup

# Change ownership of the working directory to the new user
RUN chown -R wrkuser:wrkgroup /data

# Switch to the non-root user
USER wrkuser

# Copy the wrk binary from the builder image
COPY --from=builder /tmp/wrk/wrk /usr/local/bin/wrk

# Run wrk tool by default
ENTRYPOINT ["wrk"]
