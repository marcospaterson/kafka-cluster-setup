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

check_consumer_lag() {
    info "Checking consumer group lag..."
    
    if docker exec kafka /opt/bitnami/kafka/bin/kafka-consumer-groups.sh \
        --bootstrap-server localhost:9092 \
        --describe --all-groups 2>/dev/null; then
        success "Consumer lag check completed"
    else
        warning "No consumer groups found or Kafka not accessible"
        info "This is normal if no consumers are currently active"
        
        # Show topics as alternative information
        info "Available topics:"
        docker exec kafka /opt/bitnami/kafka/bin/kafka-topics.sh \
            --bootstrap-server localhost:9092 \
            --list 2>/dev/null || warning "Could not list topics"
    fi
}

main() {
    info "Consumer Lag Monitoring for Kafka Cluster"
    echo "==========================================="
    echo
    
    check_consumer_lag
    
    echo
    info "To create a consumer group, try:"
    info "  kcat -C -b localhost:9092 -t test-topic -G my-group"
    info "Or use the Kafka console consumer:"
    info "  docker exec -it kafka /opt/bitnami/kafka/bin/kafka-console-consumer.sh \\"
    info "    --bootstrap-server localhost:9092 \\"
    info "    --topic test-topic \\"
    info "    --group my-consumer-group"
}

main "$@"
