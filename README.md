# Apache Kafka Cluster with Monitoring

A production-ready Apache Kafka cluster setup with comprehensive monitoring using Docker Compose. This setup includes Kafka 3.7.0 with KRaft mode (no Zookeeper required), Prometheus, Grafana, and specialized exporters for complete observability.

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│ Docker Host                             │
│ ┌─────────────────────────────────────┐ │
│ │ Apache Kafka 3.7.0 (KRaft)         │ │
│ │ Port: 9092 (external)              │ │
│ │ Port: 9094 (internal)              │ │
│ │ Persistent Volume: kafka_data       │ │
│ └─────────────────────────────────────┘ │
│ ┌─────────────────────────────────────┐ │
│ │ Monitoring Stack                    │ │
│ │ ┌─────────────────────────────────┐ │ │
│ │ │ Prometheus (9090)               │ │ │
│ │ │ Grafana (3000)                  │ │ │
│ │ │ Kafka Exporter (9308)           │ │ │
│ │ │ Node Exporter (9100)            │ │ │
│ │ └─────────────────────────────────┘ │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose installed
- At least 4GB RAM available
- Ports 3000, 9090, 9092, 9094, 9100, 9308 available

### Deploy the Stack

```bash
# Clone the repository
git clone <repository-url>
cd kafka-cluster-setup

# Start all services
docker compose up -d

# Create topics
./scripts/create-topics.sh

# Run smoke tests
./scripts/smoke-test.sh

# Check consumer lag (optional)
./scripts/check-lag.sh
```

## 📊 Access Points

Once deployed, you can access:

- **Kafka Broker**: `localhost:9092`
- **Grafana Dashboard**: http://localhost:3000 (admin/admin123)
- **Prometheus**: http://localhost:9090
- **Kafka Exporter Metrics**: http://localhost:9308/metrics
- **Node Exporter Metrics**: http://localhost:9100/metrics

## 🎯 What's Included

### Apache Kafka 3.7.0
- **KRaft mode** (no Zookeeper dependency)
- **Bitnami image** for production reliability
- **Performance tuned** for high throughput
- **Health checks** for automatic recovery

### Monitoring Stack
- **Prometheus** - Metrics collection and storage
- **Grafana** - Visualization and dashboards
- **Kafka Exporter** - Kafka-specific metrics
- **Node Exporter** - System resource metrics

### Automation Scripts
- **create-topics.sh** - Creates predefined topics with optimal configurations
- **smoke-test.sh** - End-to-end validation of all components
- **check-lag.sh** - Consumer group lag monitoring

### Pre-configured Topics

The setup creates the following topics optimized for different use cases:

| Topic | Partitions | Retention | Compression | Use Case |
|-------|------------|-----------|-------------|----------|
| `quotes` | 6 | 1 hour | LZ4 | High-frequency market data |
| `pricing-requests` | 3 | 24 hours | Snappy | Request/response pattern |
| `pricing-results` | 3 | 24 hours (compacted) | None | Latest state per key |
| `audit-logs` | 2 | 31 days | GZIP | Compliance and auditing |
| `errors` | 1 | 7 days | GZIP | Error handling and alerts |
| `test-topic` | 1 | 1 hour | None | Testing and validation |

## 🔧 Configuration

### Environment Variables

You can customize the deployment by setting environment variables:

```bash
# Kafka configuration
export KAFKA_HEAP_OPTS="-Xmx2G -Xms2G"  # Adjust based on available RAM

# Grafana credentials
export GF_SECURITY_ADMIN_PASSWORD="your-secure-password"
```

### Network Configuration

The setup uses an isolated Docker network (`172.20.0.0/16`) for security. To access from external hosts, update the `KAFKA_CFG_ADVERTISED_LISTENERS` in `docker-compose.yml`:

```yaml
environment:
  KAFKA_CFG_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092,EXTERNAL://YOUR_HOST_IP:9094
```

## 🧪 Testing

### Producer/Consumer Testing

```bash
# Install kcat (kafkacat) for testing
# Ubuntu/Debian: apt install kafkacat
# macOS: brew install kcat

# Produce messages
echo "Hello Kafka" | kcat -P -b localhost:9092 -t test-topic

# Consume messages
kcat -C -b localhost:9092 -t test-topic -o beginning

# Or use Docker exec
docker exec -it kafka /opt/bitnami/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server localhost:9092 --topic test-topic

docker exec -it kafka /opt/bitnami/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 --topic test-topic --from-beginning
```

### Performance Testing

```bash
# Test throughput
docker exec kafka /opt/bitnami/kafka/bin/kafka-producer-perf-test.sh \
  --topic test-topic \
  --num-records 10000 \
  --record-size 1024 \
  --throughput 1000 \
  --producer-props bootstrap.servers=localhost:9092

# Test consumer performance
docker exec kafka /opt/bitnami/kafka/bin/kafka-consumer-perf-test.sh \
  --topic test-topic \
  --messages 10000 \
  --bootstrap-server localhost:9092
```

## 📈 Monitoring

### Grafana Dashboards

The setup includes a comprehensive Kafka monitoring dashboard with:

- **Broker Health**: Availability and leadership status
- **Topic Metrics**: Message rates, partition counts
- **Consumer Lag**: Real-time lag monitoring
- **System Resources**: CPU, memory, disk usage

### Key Metrics to Monitor

- `kafka_brokers` - Number of active brokers
- `kafka_topic_partitions` - Partition count per topic
- `kafka_consumer_lag_sum` - Consumer group lag
- `kafka_server_brokertopicmetrics_messagesin_total` - Message throughput

### Alerts

Set up alerts in Grafana for:
- High consumer lag (> 1000 messages)
- Low message throughput
- Broker unavailability
- Disk space usage (> 80%)

## 🛠️ Operational Tasks

### Scaling Topics

```bash
# Increase partitions for existing topic
docker exec kafka /opt/bitnami/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --alter --topic quotes --partitions 12
```

### Managing Consumer Groups

```bash
# List consumer groups
docker exec kafka /opt/bitnami/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 --list

# Reset consumer group offset
docker exec kafka /opt/bitnami/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --group my-group --reset-offsets --to-earliest --topic test-topic --execute
```

### Backup and Recovery

```bash
# Backup Kafka data
docker run --rm -v kafka-cluster-setup_kafka_data:/data \
  -v $(pwd):/backup alpine \
  tar czf /backup/kafka-backup-$(date +%Y%m%d).tar.gz /data

# Restore Kafka data (stop containers first)
docker compose down
docker run --rm -v kafka-cluster-setup_kafka_data:/data \
  -v $(pwd):/backup alpine \
  tar xzf /backup/kafka-backup-YYYYMMDD.tar.gz -C /
docker compose up -d
```

## 🔍 Troubleshooting

### Common Issues

**Containers won't start:**
```bash
# Check logs
docker compose logs kafka
docker compose logs prometheus

# Check port conflicts
netstat -tlnp | grep -E "(3000|9090|9092)"
```

**Kafka not accessible:**
```bash
# Verify container is running
docker ps | grep kafka

# Test internal connectivity
docker exec kafka /opt/bitnami/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 --list
```

**Monitoring not working:**
```bash
# Check Prometheus targets
curl -s http://localhost:9090/targets

# Verify exporters
curl -s http://localhost:9308/metrics | grep kafka_brokers
curl -s http://localhost:9100/metrics | grep node_
```

### Performance Issues

- **High CPU/Memory**: Adjust `KAFKA_HEAP_OPTS` and container resource limits
- **Slow consumers**: Check consumer group lag and scaling
- **Disk I/O**: Monitor disk usage and consider log retention policies

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🔗 Related Resources

- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Bitnami Kafka Docker Image](https://hub.docker.com/r/bitnami/kafka)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
