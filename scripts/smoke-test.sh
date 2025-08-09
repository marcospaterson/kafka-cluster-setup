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

# Test container health
test_containers() {
    info "Testing container health..."
    
    local containers=("kafka" "prometheus" "grafana" "kafka-exporter" "node-exporter")
    local failed=false
    
    for container in "${containers[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            if [ "$(docker inspect --format='{{.State.Health.Status}}' $container 2>/dev/null || echo 'unknown')" = "healthy" ] || \
               [ "$(docker inspect --format='{{.State.Status}}' $container)" = "running" ]; then
                success "Container $container is running"
            else
                error "Container $container is not healthy"
                failed=true
            fi
        else
            error "Container $container is not running"
            failed=true
        fi
    done
    
    if [ "$failed" = true ]; then
        return 1
    fi
}

# Test Kafka connectivity
test_kafka_connectivity() {
    info "Testing Kafka connectivity..."
    
    # Test metadata retrieval
    if kcat -b localhost:9092 -L > /dev/null 2>&1; then
        success "Kafka metadata accessible"
    else
        warning "kcat not available, trying docker exec..."
        if docker exec kafka /opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list > /dev/null 2>&1; then
            success "Kafka accessible via docker exec"
        else
            error "Kafka connectivity failed"
            return 1
        fi
    fi
}

# Test producer/consumer functionality
test_producer_consumer() {
    info "Testing producer/consumer functionality..."
    
    local test_topic="test-topic"
    local test_message="Test message from Apache Kafka $(date)"
    
    # Send test message
    if kcat -P -b localhost:9092 -t "$test_topic" <<< "$test_message" 2>/dev/null; then
        # Verify message receipt
        local received=$(kcat -C -b localhost:9092 -t "$test_topic" -o beginning -e 2>/dev/null | tail -1)
        
        if [ "$received" = "$test_message" ]; then
            success "Producer/Consumer test passed with kcat"
            return 0
        fi
    fi
    
    # Fallback to docker exec method
    warning "kcat method failed, trying docker exec..."
    
    # Send test message via docker
    if echo "$test_message" | docker exec -i kafka /opt/bitnami/kafka/bin/kafka-console-producer.sh \
        --bootstrap-server localhost:9092 \
        --topic "$test_topic" 2>/dev/null; then
        
        # Verify message
        local received=$(docker exec kafka /opt/bitnami/kafka/bin/kafka-console-consumer.sh \
            --bootstrap-server localhost:9092 \
            --topic "$test_topic" \
            --from-beginning \
            --max-messages 1 \
            --timeout-ms 5000 2>/dev/null | tail -1)
        
        if [[ "$received" == *"Test message"* ]]; then
            success "Producer/Consumer test passed via docker"
        else
            error "Message verification failed"
            return 1
        fi
    else
        error "Producer test failed"
        return 1
    fi
}

# Test monitoring endpoints
test_monitoring_endpoints() {
    info "Testing monitoring endpoints..."
    
    # Test Prometheus metrics
    if curl -s http://localhost:9090/metrics | grep -q "prometheus_" 2>/dev/null; then
        success "Prometheus metrics available"
    else
        error "Prometheus metrics not accessible"
        return 1
    fi
    
    # Test Kafka exporter
    if curl -s http://localhost:9308/metrics | grep -q "kafka_brokers" 2>/dev/null; then
        success "Kafka exporter functional"
    else
        warning "Kafka exporter metrics not yet available (may need time to initialize)"
    fi
    
    # Test Grafana accessibility  
    if curl -s http://localhost:3000/api/health | grep -q "ok" 2>/dev/null; then
        success "Grafana dashboard accessible"
    else
        warning "Grafana not yet fully initialized"
    fi
}

# Main test execution
main() {
    info "Starting comprehensive smoke tests..."
    echo
    
    local failed=false
    
    test_containers || failed=true
    echo
    
    test_kafka_connectivity || failed=true
    echo
    
    test_producer_consumer || failed=true
    echo
    
    test_monitoring_endpoints || failed=true
    echo
    
    if [ "$failed" = true ]; then
        error "Some tests failed. Check the output above for details."
        exit 1
    else
        success "All smoke tests passed successfully!"
        info "Your Kafka cluster is ready for use."
        info "Access Grafana at: http://localhost:3000 (admin/admin123)"
        info "Access Prometheus at: http://localhost:9090"
        info "Kafka is available at: localhost:9092"
    fi
}

main "$@"
