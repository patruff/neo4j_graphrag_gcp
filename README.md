# Neo4j GraphRAG on GCP - 100% Free Tier POC

[![GraphRAG Test](https://github.com/YOUR_USERNAME/neo4j_graphrag_gcp/actions/workflows/test_graphrag.yml/badge.svg)](https://github.com/YOUR_USERNAME/neo4j_graphrag_gcp/actions/workflows/test_graphrag.yml)

A **100% free**, production-ready **Pure Neo4j GraphRAG** architecture deployed on Google Cloud Platform's Always Free Tier, designed to eliminate "Silent Failures" in RAG systems by combining vector search with graph relationships in a single database.

---

## 🎯 Executive Summary

This repository demonstrates a complete Infrastructure-as-Code (IaC) solution for deploying a **self-healing GraphRAG system** that addresses the critical problem of silent failures in traditional split-stack RAG architectures (e.g., Pinecone + Neo4j).

**Key Benefits:**
- **Unified Architecture**: Single Neo4j database for both vector search and graph relationships
- **100% Free Deployment**: Configured for GCP Always Free Tier (e2-micro, 30GB disk, $0/month)
- **Free Automated Testing**: GitHub Actions workflow tests GraphRAG functionality on every commit
- **Self-Healing**: Automatic recovery from reboots with persistent data storage
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
│       └── test_graphrag.yml      # Simple GraphRAG test with Neo4j
├── terraform/
│   ├── main.tf                    # GCP infrastructure (optional)
│   ├── variables.tf               # Configurable parameters
│   ├── outputs.tf                 # Deployment outputs
│   └── cloud-init.yml             # VM initialization script
├── src/
│   ├── rag_test.py                # GraphRAG round-trip test (mock embeddings)
│   ├── vertex_ai_example.py       # Production example with Vertex AI
│   ├── requirements.txt           # Python dependencies (free testing)
│   └── requirements-vertexai.txt  # Vertex AI dependencies (production)
├── docker-compose.yml             # Local development setup
├── SAMPLE_QUERIES.md              # Knowledge graph vs vector search examples
├── VERTEX_AI_SETUP.md             # Production setup with Google Vertex AI
├── CONTRIBUTING.md                # Contribution guidelines
├── .gitignore
└── README.md
```

---

## 🚀 Quick Start

### Prerequisites

**For Local Testing (Free):**
- **Python** >= 3.11
- **Docker** and Docker Compose

**For GCP Deployment (Optional):**
- **GCP Account** with billing enabled
- **gcloud CLI** installed and configured
- **Terraform** >= 1.5.0

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

### Production Setup with Vertex AI (Optional)

For **production use** with **real embeddings and LLM**, see [VERTEX_AI_SETUP.md](VERTEX_AI_SETUP.md) for complete instructions on using Google Vertex AI:

- **Real embeddings** with `textembedding-gecko` or `text-embedding-004`
- **Gemini LLM** for answer generation
- **GraphRAG pipeline** with production-ready models
- **Cost**: ~$1-5/month for experimentation (NOT free tier)

```bash
# Quick start with Vertex AI
pip install neo4j-graphrag[google]
export GCP_PROJECT_ID="your-project-id"
python src/vertex_ai_example.py
```

The repository uses **mock embeddings by default** (100% free) for testing. Vertex AI is **optional** for production deployments.

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

### 🆓 GCP Always Free Tier Configuration

This deployment is configured to run **100% FREE** within GCP's Always Free tier limits:

- **Compute**: 1 non-preemptible **e2-micro** VM instance (0.25-2 vCPU, 1 GB RAM)
- **Storage**: 30GB standard persistent disk
- **Region**: us-central1 (also eligible: us-west1, us-east1)
- **Network**: 1GB outbound data transfer per month
- **Neo4j Memory**: Optimized for 1GB RAM (128MB heap, 256MB pagecache)

**Estimated Monthly Cost**: **$0** (within free tier limits) ✅

**Free Tier Eligibility Requirements:**
- Must be non-preemptible (regular VM, not Spot)
- Must use e2-micro machine type
- Maximum 30GB standard persistent disk
- Must be in us-central1, us-west1, or us-east1
- Stay under 1GB network egress per month

### High Availability Features

1. **Self-Healing**: Metadata startup script automatically restarts Neo4j on boot
2. **Persistent Storage**: Neo4j data stored on boot disk, survives reboots
3. **Automatic Restart**: Cloud-init ensures Docker Compose starts on boot
4. **Standard VM**: Non-preemptible for consistent uptime (required for free tier)

### Security

- **Firewall Rules**: Only ports 22 (SSH), 7474 (HTTP), 7687 (Bolt) accessible
- **IP Whitelisting**: Access restricted to specified IP addresses
- **Service Account**: Minimal permissions (logging + monitoring only)
- **Encrypted Storage**: All persistent disks encrypted at rest by default
- **No Public SSH Keys**: Project-wide SSH keys disabled

---

## 🧪 Testing & Validation

The `rag_test.py` script performs a comprehensive **round-trip verification** using **mock embeddings** (deterministic random vectors for testing).

**Note:** This test uses mock embeddings to ensure 100% free operation. For production use with **real embeddings**, see [VERTEX_AI_SETUP.md](VERTEX_AI_SETUP.md) to integrate Google Vertex AI.

### Test Suite

| Test # | Name | Purpose |
|--------|------|---------|
| 1 | Connection Verification | Ensure database connectivity |
| 2 | Database Initialization | Create vector index and clear existing data |
| 3 | Data Ingestion | Insert health documents with embeddings and relationships |
| 4 | Hybrid Vector + Graph Search | Verify vector search returns correct results with graph context |
| 5 | **Knowledge Graph Traversal** | **Demonstrate queries impossible with pure vector search** |
| 6 | Data Consistency Verification | Ensure all nodes have embeddings and relationships intact |

### Sample Data

The test uses realistic HealthTech entities with rich relationships:

**Entities (9 nodes):**
- **People:** Dr. Sarah Chen (Cardiologist), Dr. Marcus Liu (Researcher)
- **Organizations:** Cardiology Department, Clinical Research Team
- **Documents:** Q1 Arrhythmia Treatment Protocol, Beta-Blocker Efficacy Study
- **Medical:** Arrhythmia (Symptom), Beta-Blocker Therapy (Treatment), Atrial Fibrillation (Diagnosis)

**Relationships (17 edges):**
- Medical: `TREATED_BY`, `MANIFESTS_AS`
- Authorship: `AUTHORED_BY`, `CONTRIBUTED_BY`
- Content: `DISCUSSES`, `ANALYZES`, `FOCUSES_ON`
- Organizational: `WORKS_IN`, `COLLABORATES_WITH`, `TREATS`, `STUDIES`

### Knowledge Graph Query Example

Test 5 demonstrates a query **impossible with pure vector search**:

```cypher
// "Find documents authored by people in Cardiology who discuss Arrhythmia"
MATCH (dept:HealthEntity {name: 'Cardiology Department'})
MATCH (person:HealthEntity)-[:WORKS_IN]->(dept)
MATCH (doc:HealthEntity)-[:AUTHORED_BY]->(person)
MATCH (doc)-[:DISCUSSES]->(topic:HealthEntity {name: 'Arrhythmia'})
RETURN doc.name, person.name, dept.name
```

This multi-hop traversal query requires understanding entity relationships - something vector search alone cannot do.

### Expected Output

```
✓ Connection Verification (12.34ms)
✓ Database Initialization (1,234.56ms)
✓ Data Ingestion (234.56ms)
✓ Hybrid Vector + Graph Search (45.67ms)
✓ Knowledge Graph Traversal (23.45ms) [IMPOSSIBLE with vector-only!]
✓ Data Consistency Verification (18.90ms)

6/6 tests passed
```

### Sample Queries

See [SAMPLE_QUERIES.md](SAMPLE_QUERIES.md) for comprehensive examples showing:
- Pure vector search queries
- Knowledge graph traversal queries
- Hybrid queries combining both
- Comparison: What vector search CAN'T do vs what GraphRAG CAN do

---

<!-- TEST_RESULTS_START -->
## 🧪 Test Results

**Latest Test Run:** *Awaiting CI/CD execution*

This section will be automatically updated by GitHub Actions after each successful test run.

<!-- TEST_RESULTS_END -->

---

## 🔄 Automated Testing

The GitHub Actions workflow (`.github/workflows/test_graphrag.yml`) provides a **simple, free GraphRAG test** that runs on every push and pull request.

### What It Does

1. **Spins up Neo4j** in a Docker service container (free on GitHub runners)
2. **Installs dependencies** and runs the complete GraphRAG test suite
3. **Generates test report** with pass/fail status and latency metrics
4. **Displays results** in the GitHub Actions job summary

### Zero Configuration Required

No secrets needed! The workflow uses a Neo4j service container with default test credentials. Just push your code and the tests run automatically.

### View Test Results

- Check the **Actions** tab in your GitHub repository
- Each run shows a complete test report in the job summary
- Test artifacts are saved for 30 days

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
