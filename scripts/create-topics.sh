#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

create_topic() {
    local topic_name="$1"
    local partitions="$2"
    local replication_factor="$3"
    shift 3
    local configs="$@"
    
    info "Creating topic: $topic_name with $partitions partitions"
    
    if docker exec kafka /opt/bitnami/kafka/bin/kafka-topics.sh \
        --create \
        --bootstrap-server localhost:9092 \
        --topic "$topic_name" \
        --partitions "$partitions" \
        --replication-factor "$replication_factor" \
        $configs 2>/dev/null; then
        success "Topic '$topic_name' created successfully"
    else
        if docker exec kafka /opt/bitnami/kafka/bin/kafka-topics.sh \
            --bootstrap-server localhost:9092 \
            --describe \
            --topic "$topic_name" >/dev/null 2>&1; then
            warning "Topic '$topic_name' already exists"
        else
            error "Failed to create topic '$topic_name'"
            return 1
        fi
    fi
}

main() {
    info "Starting topic creation for Kafka cluster..."
    
    # High-throughput streaming topics
    create_topic "quotes" 6 1 \
        --config retention.ms=3600000 \
        --config compression.type=lz4 \
        --config cleanup.policy=delete
    
    # Request/response topics
    create_topic "pricing-requests" 3 1 \
        --config retention.ms=86400000 \
        --config compression.type=snappy \
        --config cleanup.policy=delete
    
    # Compacted state topics
    create_topic "pricing-results" 3 1 \
        --config retention.ms=86400000 \
        --config cleanup.policy=compact \
        --config min.cleanable.dirty.ratio=0.1
    
    # Audit and compliance topics
    create_topic "audit-logs" 2 1 \
        --config retention.ms=2678400000 \
        --config compression.type=gzip \
        --config cleanup.policy=delete
    
    # Error handling topics
    create_topic "errors" 1 1 \
        --config retention.ms=604800000 \
        --config compression.type=gzip \
        --config cleanup.policy=delete
    
    # Test topic for validation
    create_topic "test-topic" 1 1 \
        --config retention.ms=3600000 \
        --config cleanup.policy=delete
    
    success "All topics created successfully!"
    
    info "Listing all topics:"
    docker exec kafka /opt/bitnami/kafka/bin/kafka-topics.sh \
        --bootstrap-server localhost:9092 \
        --list
}

main "$@"
