# Using Vertex AI with Neo4j GraphRAG

This guide shows how to use **real embeddings and LLM** from Google Vertex AI instead of mock embeddings for production GraphRAG applications.

---

## 🎯 Why Vertex AI?

**Benefits:**
- ✅ **Integrated with GCP**: Same platform as your Neo4j deployment
- ✅ **Enterprise-grade**: Production-ready embeddings and LLMs
- ✅ **Cost-effective**: Pay-per-use pricing, no minimum commitments
- ✅ **Multiple models**: Access to Gemini (LLM) and textembedding-gecko (embeddings)
- ✅ **GraphRAG native**: Built-in support in neo4j-graphrag package

**Free Tier Note:**
- Vertex AI is **NOT** part of GCP Always Free Tier
- You'll need to enable billing
- Typical costs: ~$0.0001/1K characters (embeddings), ~$0.001-0.01/1K tokens (Gemini)
- Estimate: $1-5/month for small-scale experimentation

---

## 🚀 Quick Start

### 1. Enable Vertex AI API

```bash
# Set your project
export GCP_PROJECT_ID="your-project-id"

# Enable Vertex AI API
gcloud services enable aiplatform.googleapis.com --project=$GCP_PROJECT_ID

# Verify it's enabled
gcloud services list --enabled --project=$GCP_PROJECT_ID | grep aiplatform
```

### 2. Set up Authentication

**Option A: Application Default Credentials (Local Development)**
```bash
gcloud auth application-default login
```

**Option B: Service Account (Production)**
```bash
# Create service account
gcloud iam service-accounts create neo4j-graphrag-sa \
    --display-name="Neo4j GraphRAG Service Account" \
    --project=$GCP_PROJECT_ID

# Grant Vertex AI User role
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --member="serviceAccount:neo4j-graphrag-sa@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/aiplatform.user"

# Create and download key
gcloud iam service-accounts keys create vertex-ai-key.json \
    --iam-account=neo4j-graphrag-sa@$GCP_PROJECT_ID.iam.gserviceaccount.com

# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/vertex-ai-key.json"
```

### 3. Install Dependencies

```bash
# Install Neo4j GraphRAG with Google/Vertex AI support
pip install neo4j-graphrag[google]

# Or use the requirements file
pip install -r src/requirements-vertexai.txt
```

### 4. Run the Example

```bash
# Set required environment variables
export GCP_PROJECT_ID="your-project-id"
export GCP_LOCATION="us-central1"  # or your preferred region
export NEO4J_URI="bolt://localhost:7687"
export NEO4J_PASSWORD="your_password"

# Run the Vertex AI example
python src/vertex_ai_example.py
```

---

## 📊 Available Models

### Embeddings Models

| Model | Dimensions | Use Case | Cost (per 1K chars) |
|-------|-----------|----------|---------------------|
| `textembedding-gecko@003` | 768 | General purpose | ~$0.0001 |
| `textembedding-gecko-multilingual@001` | 768 | Multilingual | ~$0.0001 |
| `text-embedding-004` | 768 | Latest, improved quality | ~$0.00002 |

**Recommendation:** Use `text-embedding-004` for best quality/price ratio.

### LLM Models (Gemini)

| Model | Context Window | Use Case | Cost (per 1M tokens) |
|-------|---------------|----------|----------------------|
| `gemini-3-flash-preview` ⭐ | 1M tokens | **Latest! Best reasoning + speed** | Input: $0.075, Output: $0.30 |
| `gemini-1.5-flash` | 1M tokens | Fast, cost-effective | Input: $0.075, Output: $0.30 |
| `gemini-1.5-pro` | 2M tokens | Complex reasoning | Input: $1.25, Output: $5.00 |
| `gemini-2.0-flash-exp` | 1M tokens | Experimental (deprecated) | Free (during preview) |

**Recommendation:** Use `gemini-3-flash-preview` for best performance. It combines Gemini 3 Pro's reasoning with Flash's speed and cost-efficiency.

**Gemini 3 Flash Features:**
- **Thinking levels**: Control internal reasoning (minimal, low, medium, high)
- **Enhanced multimodal**: Better image, video, audio processing (up to "ultra high" resolution)
- **Streaming function calls**: Improved tool use with partial argument streaming
- **1M+ token context**: Up to 1,048,576 input tokens, 65,536 output tokens

---

## 💻 Code Examples

### Basic Vector Search with Vertex AI

```python
from neo4j import GraphDatabase
from neo4j_graphrag.retrievers import VectorRetriever
from neo4j_graphrag.embeddings import VertexAIEmbeddings
from neo4j_graphrag.llm import VertexAILLM
from neo4j_graphrag.generation import GraphRAG
from vertexai.generative_models import GenerationConfig

# Connect to Neo4j
driver = GraphDatabase.driver("bolt://localhost:7687", auth=("neo4j", "password"))

# Initialize Vertex AI Embeddings
embedder = VertexAIEmbeddings(
    model_name="text-embedding-004",
    project="your-project-id",
    location="us-central1"
)

# Initialize retriever
retriever = VectorRetriever(
    driver=driver,
    index_name="health_vector_index",
    embedder=embedder
)

# Initialize Gemini 3 Flash LLM (latest model)
generation_config = GenerationConfig(
    temperature=0.0,
    top_p=0.95,
    top_k=64,  # Fixed at 64 for Gemini 3
    max_output_tokens=8192,
)

llm = VertexAILLM(
    model_name="gemini-3-flash-preview",  # Latest Gemini 3 Flash
    generation_config=generation_config,
    project="your-project-id",
    location="us-central1"
)

# Create GraphRAG pipeline
rag = GraphRAG(retriever=retriever, llm=llm)

# Query
response = rag.search("What treatments are available for arrhythmia?", retriever_config={"top_k": 5})
print(response.answer)
```

### Using Gemini 3 Flash Thinking Levels

Gemini 3 Flash supports **thinking levels** to control the amount of internal reasoning:

```python
from vertexai.generative_models import GenerationConfig

# Minimal thinking: Fastest, lowest cost (similar to Flash behavior)
generation_config = GenerationConfig(
    temperature=0.0,
    thinking_level="MINIMAL"  # Options: MINIMAL, LOW, MEDIUM, HIGH
)

llm = VertexAILLM(
    model_name="gemini-3-flash-preview",
    generation_config=generation_config,
    project="your-project-id",
    location="us-central1"
)

# For complex GraphRAG queries requiring deeper reasoning
generation_config_high = GenerationConfig(
    temperature=0.0,
    thinking_level="HIGH"  # More reasoning, higher latency & cost
)

llm_reasoning = VertexAILLM(
    model_name="gemini-3-flash-preview",
    generation_config=generation_config_high,
    project="your-project-id",
    location="us-central1"
)
```

**When to use different thinking levels:**
- `MINIMAL`: Simple queries, fast responses, lowest cost
- `LOW`: Standard GraphRAG queries (default for most use cases)
- `MEDIUM`: Complex multi-hop graph traversal reasoning
- `HIGH`: Very complex analytical queries requiring deep reasoning

### Hybrid Search with Graph Traversal

```python
from neo4j_graphrag.retrievers import VectorCypherRetriever

# Define retrieval query to traverse graph
retrieval_query = """
MATCH (node)-[:AUTHORED_BY]->(author:Person)
MATCH (node)-[:DISCUSSES]->(topic)
RETURN
    node.name AS document,
    node.description AS summary,
    author.name AS author,
    collect(topic.name) AS topics,
    score
"""

# Initialize retriever with graph context
retriever = VectorCypherRetriever(
    driver=driver,
    index_name="health_vector_index",
    embedder=embedder,
    retrieval_query=retrieval_query
)

# Use in GraphRAG
rag = GraphRAG(retriever=retriever, llm=llm)
response = rag.search("Who wrote about beta-blockers?", return_context=True)

print(f"Answer: {response.answer}")
print(f"\nContext from graph:")
for item in response.retriever_result.items:
    print(f"- {item.content}")
```

### Creating Vector Index for Vertex AI Embeddings

```python
from neo4j_graphrag.indexes import create_vector_index

# Create vector index with 768 dimensions (for textembedding-gecko)
create_vector_index(
    driver,
    name="health_vector_index",
    label="HealthEntity",
    embedding_property="embedding",
    dimensions=768,  # Must match your embedding model!
    similarity_fn="cosine"
)
```

### Populating Index with Vertex AI Embeddings

```python
from neo4j_graphrag.embeddings import VertexAIEmbeddings

embedder = VertexAIEmbeddings(
    model_name="text-embedding-004",
    project="your-project-id"
)

# Sample health data
documents = [
    "Arrhythmia is an irregular heartbeat requiring medical attention",
    "Beta-blockers are medications that reduce heart rate",
    "Atrial fibrillation is a type of arrhythmia"
]

# Generate embeddings
embeddings = embedder.embed_query(documents[0])  # Single query
# or
batch_embeddings = [embedder.embed_query(doc) for doc in documents]

# Store in Neo4j (with your existing nodes)
with driver.session() as session:
    for i, (doc, embedding) in enumerate(zip(documents, batch_embeddings)):
        session.run("""
            MATCH (n:HealthEntity)
            WHERE id(n) = $node_id
            SET n.embedding = $embedding
        """, node_id=i, embedding=embedding)
```

---

## 🔐 Security Best Practices

### Never Commit Credentials

```bash
# Add to .gitignore
echo "vertex-ai-key.json" >> .gitignore
echo "*.json" >> .gitignore  # If not already present
echo ".env" >> .gitignore
```

### Use Environment Variables

```bash
# Create .env file (not committed)
cat > .env <<EOF
GCP_PROJECT_ID=your-project-id
GCP_LOCATION=us-central1
GOOGLE_APPLICATION_CREDENTIALS=/path/to/vertex-ai-key.json
NEO4J_URI=bolt://localhost:7687
NEO4J_PASSWORD=your_password
EOF

# Load in your app
from dotenv import load_dotenv
load_dotenv()
```

### Restrict Service Account Permissions

```bash
# Minimum required role for Vertex AI
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --member="serviceAccount:neo4j-graphrag-sa@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/aiplatform.user"

# Do NOT grant broader roles like Editor or Owner
```

---

## 💰 Cost Optimization

### 1. Choose the Right Model

```python
# For development/testing: Use smaller, cheaper models
embedder = VertexAIEmbeddings(model_name="textembedding-gecko@003")  # $0.0001/1K chars
llm = VertexAILLM(model_name="gemini-3-flash-preview")  # Latest, best value

# For production: Best quality and cost
embedder = VertexAIEmbeddings(model_name="text-embedding-004")  # Best quality/price: $0.00002/1K chars
llm = VertexAILLM(model_name="gemini-3-flash-preview")  # Best reasoning + speed
```

### 2. Batch Embeddings

```python
# ❌ Inefficient: Embed one at a time
for doc in documents:
    embedding = embedder.embed_query(doc)

# ✅ Efficient: Batch processing
# Note: Check Vertex AI limits for batch size
batch_size = 100
for i in range(0, len(documents), batch_size):
    batch = documents[i:i+batch_size]
    embeddings = [embedder.embed_query(doc) for doc in batch]
```

### 3. Cache Embeddings

```python
# Store embeddings in Neo4j - don't regenerate!
with driver.session() as session:
    session.run("""
        MATCH (n:HealthEntity)
        WHERE n.embedding IS NULL
        SET n.embedding = $embedding
    """, embedding=embedding)
```

### 4. Monitor Costs

```bash
# View Vertex AI costs in GCP Console
gcloud billing accounts list
gcloud billing projects describe $GCP_PROJECT_ID

# Or use the GCP Console:
# https://console.cloud.google.com/billing
```

---

## 🐛 Troubleshooting

### Error: "google.auth.exceptions.DefaultCredentialsError"

**Solution:**
```bash
gcloud auth application-default login
# or
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/key.json"
```

### Error: "Permission denied on Vertex AI"

**Solution:**
```bash
# Grant the required role
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --member="serviceAccount:YOUR_SA@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/aiplatform.user"
```

### Error: "Dimension mismatch in vector index"

**Solution:** The vector index dimensions must match your embedding model:
- `textembedding-gecko@003`: 768 dimensions
- `text-embedding-004`: 768 dimensions

Recreate the index with correct dimensions:
```python
from neo4j_graphrag.indexes import drop_index_if_exists, create_vector_index

drop_index_if_exists(driver, "health_vector_index")
create_vector_index(driver, "health_vector_index", dimensions=768, ...)
```

### Error: "API not enabled"

**Solution:**
```bash
gcloud services enable aiplatform.googleapis.com --project=$GCP_PROJECT_ID
```

---

## 📚 Additional Resources

- [Neo4j GraphRAG Documentation](https://neo4j.com/docs/neo4j-graphrag-python/current/)
- [Vertex AI Pricing](https://cloud.google.com/vertex-ai/pricing)
- [Gemini API Documentation](https://cloud.google.com/vertex-ai/docs/generative-ai/model-reference/gemini)
- [Text Embeddings API](https://cloud.google.com/vertex-ai/docs/generative-ai/embeddings/get-text-embeddings)

---

## 🔄 Migration from Mock Embeddings

If you've been using the mock embeddings in `rag_test.py`, here's how to migrate:

1. **Recreate the vector index with 768 dimensions** (instead of 1536)
2. **Generate real embeddings for your data** using Vertex AI
3. **Update your application code** to use `VertexAIEmbeddings`

See the `vertex_ai_example.py` script for a complete working example.

---

**Ready to get started?** Run `python src/vertex_ai_example.py` after setting up your GCP credentials!
