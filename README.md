# Neo4j GraphRAG on GCP - Production POC

[![GraphRAG POC - Deploy & Test](https://github.com/YOUR_USERNAME/neo4j_graphrag_gcp/actions/workflows/deploy_and_test.yml/badge.svg)](https://github.com/YOUR_USERNAME/neo4j_graphrag_gcp/actions/workflows/deploy_and_test.yml)

A production-ready, cost-effective **Pure Neo4j GraphRAG** architecture deployed on Google Cloud Platform, designed to eliminate "Silent Failures" in RAG systems by combining vector search with graph relationships in a single database.

---

## 🎯 Executive Summary

This repository demonstrates a complete Infrastructure-as-Code (IaC) solution for deploying a **self-healing GraphRAG system** that addresses the critical problem of silent failures in traditional split-stack RAG architectures (e.g., Pinecone + Neo4j).

**Key Benefits:**
- **Unified Architecture**: Single Neo4j database for both vector search and graph relationships
- **Cost-Optimized**: Spot VM pricing on GCP (up to 80% cost reduction)
- **Self-Healing**: Automatic recovery from instance terminations with persistent data storage
- **Production-Ready**: Complete CI/CD, monitoring, and security best practices
- **Verifiable**: Automated round-trip testing ensures data consistency

---

## 🏗️ Architecture

### The Problem: Silent Failures in Split-Stack RAG

Traditional RAG architectures often use separate databases for vector search (e.g., Pinecone) and graph relationships (e.g., Neo4j). This creates:

1. **Data Synchronization Issues**: Embeddings and graph data can drift out of sync
2. **Silent Failures**: Vector search may return results that have broken graph relationships
3. **Increased Latency**: Multiple database roundtrips for hybrid queries
4. **Higher Costs**: Paying for two separate managed database services
5. **Operational Complexity**: Managing two different backup/restore procedures

### The Solution: Pure Neo4j GraphRAG

Neo4j 5.x+ includes **native vector indexing**, enabling a unified architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                     Neo4j 5.x Database                      │
│                                                             │
│  ┌──────────────────┐         ┌──────────────────┐        │
│  │  Vector Index    │         │  Graph Storage   │        │
│  │  (1536 dims)     │◄───────►│  (Relationships) │        │
│  │                  │         │                  │        │
│  │  • Cosine Sim    │         │  • TREATED_BY    │        │
│  │  • Fast KNN      │         │  • MANIFESTS_AS  │        │
│  └──────────────────┘         └──────────────────┘        │
│                                                             │
│         Single Source of Truth + ACID Guarantees           │
└─────────────────────────────────────────────────────────────┘
```

**Advantages:**
- ✅ **Atomic Operations**: Graph relationships and embeddings updated in single transactions
- ✅ **Consistency Guarantees**: No drift between vector and graph data
- ✅ **Lower Latency**: Single database query combines vector + graph search
- ✅ **Reduced Costs**: One database to manage and pay for
- ✅ **Simplified Operations**: Single backup, single monitoring system

---

## 📁 Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── deploy_and_test.yml    # CI/CD pipeline
├── terraform/
│   ├── main.tf                    # GCP infrastructure
│   ├── variables.tf               # Configurable parameters
│   ├── outputs.tf                 # Deployment outputs
│   └── cloud-init.yml             # VM initialization script
├── src/
│   ├── rag_test.py                # GraphRAG round-trip test
│   └── requirements.txt           # Python dependencies
├── docker-compose.yml             # Local development setup
├── .gitignore
└── README.md
```

---

## 🚀 Quick Start

### Prerequisites

- **GCP Account** with billing enabled
- **gcloud CLI** installed and configured
- **Terraform** >= 1.5.0
- **Python** >= 3.11 (for local testing)
- **Docker** (for local testing)

### Local Testing (No GCP Required)

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/neo4j_graphrag_gcp.git
   cd neo4j_graphrag_gcp
   ```

2. **Start Neo4j locally**
   ```bash
   export NEO4J_PASSWORD="your_secure_password"
   docker compose up -d
   ```

3. **Run the test suite**
   ```bash
   cd src
   pip install -r requirements.txt
   python rag_test.py
   ```

4. **View results**
   ```bash
   cat test_results.md
   ```

### GCP Deployment

1. **Set up GCP credentials**
   ```bash
   gcloud auth application-default login
   export GOOGLE_PROJECT="your-gcp-project-id"
   ```

2. **Configure Terraform variables**
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. **Deploy infrastructure**
   ```bash
   terraform init
   terraform plan -var="project_id=$GOOGLE_PROJECT" \
                  -var="allowed_ip=$(curl -s ifconfig.me)/32" \
                  -var="neo4j_password=YOUR_SECURE_PASSWORD"

   terraform apply -auto-approve
   ```

4. **Access Neo4j**
   ```bash
   # Get connection details
   terraform output connection_instructions

   # Open browser to the URL shown (e.g., http://YOUR_IP:7474)
   # Login with: neo4j / YOUR_SECURE_PASSWORD
   ```

---

## ⚙️ Infrastructure Details

### Cost Optimization

- **Spot VMs**: Up to 80% cheaper than regular instances
- **Right-Sized Compute**: e2-medium (2 vCPU, 4 GB RAM) sufficient for POC
- **Standard Persistent Disk**: Cost-effective storage with adequate performance
- **Ephemeral IP**: No reserved IP charges

**Estimated Monthly Cost**: $15-25 USD (depending on region and usage)

### High Availability Features

1. **Self-Healing**: Metadata startup script automatically remounts data disk and restarts Neo4j
2. **Persistent Storage**: Dedicated disk for Neo4j data survives instance termination
3. **Graceful Shutdown**: 30-second termination notice on Spot VMs allows clean shutdown
4. **Automatic Restart**: Cloud-init ensures Docker Compose starts on boot

### Security

- **Firewall Rules**: Only ports 22 (SSH), 7474 (HTTP), 7687 (Bolt) accessible
- **IP Whitelisting**: Access restricted to specified IP addresses
- **Service Account**: Minimal permissions (logging + monitoring only)
- **Encrypted Storage**: All persistent disks encrypted at rest by default
- **No Public SSH Keys**: Project-wide SSH keys disabled

---

## 🧪 Testing & Validation

The `rag_test.py` script performs a comprehensive **round-trip verification**:

### Test Suite

| Test # | Name | Purpose |
|--------|------|---------|
| 1 | Connection Verification | Ensure database connectivity |
| 2 | Database Initialization | Create vector index and clear existing data |
| 3 | Data Ingestion | Insert health documents with embeddings and relationships |
| 4 | Hybrid Vector + Graph Search | Verify vector search returns correct results with graph context |
| 5 | Data Consistency Verification | Ensure all nodes have embeddings and relationships intact |

### Sample Data

The test uses realistic HealthTech entities:

```python
Nodes:
  1. Symptom: "Arrhythmia" (with embedding)
  2. Drug: "Beta-Blocker" (with embedding)
  3. Diagnosis: "Atrial Fibrillation" (with embedding)

Relationships:
  (Arrhythmia) -[:TREATED_BY]-> (Beta-Blocker)
  (Arrhythmia) -[:MANIFESTS_AS]-> (Atrial Fibrillation)
  (Atrial Fibrillation) -[:TREATED_BY]-> (Beta-Blocker)
```

### Expected Output

```
✓ Connection Verification (12.34ms)
✓ Database Initialization (1,234.56ms)
✓ Data Ingestion (234.56ms)
✓ Hybrid Vector + Graph Search (45.67ms)
✓ Data Consistency Verification (23.45ms)

5/5 tests passed
```

---

<!-- TEST_RESULTS_START -->
## 🧪 Test Results

**Latest Test Run:** *Awaiting CI/CD execution*

This section will be automatically updated by GitHub Actions after each successful test run.

<!-- TEST_RESULTS_END -->

---

## 🔄 CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/deploy_and_test.yml`) provides:

### Stages

1. **Terraform Linting**
   - Format checking
   - Validation
   - Best practices enforcement

2. **Integration Tests**
   - Spins up Neo4j service container
   - Runs full GraphRAG test suite
   - Generates test report
   - Updates README with results

3. **GCP Deployment** *(Manual trigger only)*
   - Terraform plan & apply
   - Infrastructure provisioning
   - Deployment verification

4. **Security Scanning**
   - Trivy vulnerability scanning
   - SARIF upload to GitHub Security

### Required GitHub Secrets

Configure these in your repository settings (`Settings > Secrets and variables > Actions`):

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `GCP_CREDENTIALS` | Service account JSON key | `{"type": "service_account", ...}` |
| `GCP_PROJECT_ID` | Your GCP project ID | `my-project-12345` |
| `NEO4J_PASSWORD` | Neo4j database password | `SecureP@ssw0rd123` |
| `ALLOWED_IP` | Your IP in CIDR format | `203.0.113.42/32` |

### Creating GCP Service Account

```bash
# Set variables
export PROJECT_ID="your-gcp-project-id"
export SA_NAME="neo4j-graphrag-deployer"

# Create service account
gcloud iam service-accounts create $SA_NAME \
    --display-name="Neo4j GraphRAG Deployer" \
    --project=$PROJECT_ID

# Grant required permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/compute.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountUser"

# Create and download key
gcloud iam service-accounts keys create gcp-credentials.json \
    --iam-account=$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com

# Copy the contents of gcp-credentials.json to GCP_CREDENTIALS secret
cat gcp-credentials.json
```

---

## 🛠️ Operations Guide

### Monitoring

```bash
# SSH into the instance
gcloud compute ssh neo4j-graphrag-poc --zone=us-central1-a

# Check Neo4j status
cd /opt/neo4j
docker compose ps
docker compose logs neo4j

# View deployment logs
cat /opt/neo4j/deployment_complete.txt
cat /var/log/neo4j-startup.log
```

### Backup & Restore

```bash
# Backup Neo4j data
gcloud compute disks snapshot neo4j-graphrag-poc-data \
    --snapshot-names=neo4j-backup-$(date +%Y%m%d-%H%M%S) \
    --zone=us-central1-a

# Restore from snapshot (create new disk)
gcloud compute disks create neo4j-graphrag-poc-data-restored \
    --source-snapshot=neo4j-backup-YYYYMMDD-HHMMSS \
    --zone=us-central1-a
```

### Scaling

```bash
# Resize persistent disk (requires instance stop)
gcloud compute disks resize neo4j-graphrag-poc-data \
    --size=100GB \
    --zone=us-central1-a

# Change machine type
gcloud compute instances set-machine-type neo4j-graphrag-poc \
    --machine-type=e2-standard-2 \
    --zone=us-central1-a
```

### Troubleshooting

**Issue**: Neo4j not accessible after deployment
```bash
# Check firewall rules
gcloud compute firewall-rules list | grep neo4j

# Verify your IP
curl ifconfig.me

# Test connectivity
nc -zv YOUR_INSTANCE_IP 7687
```

**Issue**: Spot VM terminated
```bash
# Check if instance is stopped
gcloud compute instances describe neo4j-graphrag-poc \
    --zone=us-central1-a \
    --format="value(status)"

# Start it manually (data is preserved)
gcloud compute instances start neo4j-graphrag-poc \
    --zone=us-central1-a
```

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Run tests locally (`python src/rag_test.py`)
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **Neo4j Team** for native vector indexing in Neo4j 5.x
- **Google Cloud Platform** for cost-effective Spot VM infrastructure
- **HealthTech Community** for highlighting the silent failure problem in RAG systems

---

## 📞 Support

For issues, questions, or feature requests:
- **GitHub Issues**: [Create an issue](https://github.com/YOUR_USERNAME/neo4j_graphrag_gcp/issues)
- **Email**: your-email@example.com
- **Documentation**: [Neo4j Vector Search Docs](https://neo4j.com/docs/cypher-manual/current/indexes-for-vector-search/)

---

## 🗺️ Roadmap

- [ ] Add OpenAI/HuggingFace embedding integration
- [ ] Implement LangChain/LlamaIndex connectors
- [ ] Add Grafana dashboards for monitoring
- [ ] Create Terraform modules for multi-environment deployments
- [ ] Add load testing suite with Locust
- [ ] Implement automatic failover with managed instance groups

---

**Built with ❤️ for the HealthTech community**
