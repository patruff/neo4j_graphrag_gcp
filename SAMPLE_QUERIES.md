# Neo4j GraphRAG Sample Queries

This document demonstrates the power of combining **vector search** with **knowledge graph traversal** in Neo4j. These queries show what's possible with GraphRAG that's impossible with pure vector search (like Pinecone or Google File Search).

---

## 📊 Test Data Overview

The test database contains:

**Entities:**
- **People:** Dr. Sarah Chen (Cardiologist), Dr. Marcus Liu (Researcher)
- **Organizations:** Cardiology Department, Clinical Research Team
- **Documents:** Q1 Arrhythmia Treatment Protocol, Beta-Blocker Efficacy Study
- **Medical:** Arrhythmia (Symptom), Beta-Blocker Therapy (Treatment), Atrial Fibrillation (Diagnosis)

**Relationships:**
- Medical: `TREATED_BY`, `MANIFESTS_AS`
- Authorship: `AUTHORED_BY`, `CONTRIBUTED_BY`
- Content: `DISCUSSES`, `ANALYZES`, `FOCUSES_ON`
- Organizational: `WORKS_IN`, `COLLABORATES_WITH`, `TREATS`, `STUDIES`

---

## 🔍 Query Examples

### 1. Pure Vector Search (What Everyone Has)

```cypher
// Find entities similar to "heart rhythm problems"
CALL db.index.vector.queryNodes(
    'health_vector_index',
    5,
    $embedding_for_heart_rhythm_problems
) YIELD node, score
RETURN
    node.name AS entity,
    node.node_type AS type,
    score AS similarity
ORDER BY score DESC
```

**What it does:** Returns entities with similar embeddings.
**Limitation:** No understanding of WHO wrote WHAT, or WHEN, or WHY things are connected.

---

### 2. Knowledge Graph Traversal (GraphRAG Advantage)

#### Find Documents by Author's Department

```cypher
// "What documents were written by people in the Cardiology Department?"
MATCH (dept:HealthEntity {name: 'Cardiology Department'})
MATCH (person:HealthEntity)-[:WORKS_IN]->(dept)
MATCH (doc:HealthEntity)-[:AUTHORED_BY]->(person)
RETURN
    doc.name AS document,
    doc.description AS summary,
    person.name AS author,
    dept.name AS department
```

**Why vector search fails:** It can find similar text but can't traverse the organizational hierarchy.

---

#### Find Collaborations

```cypher
// "What did Dr. Sarah Chen and Dr. Marcus Liu work on together?"
MATCH (sarah:HealthEntity {name: 'Dr. Sarah Chen'})
MATCH (marcus:HealthEntity {name: 'Dr. Marcus Liu'})
MATCH (sarah)-[:COLLABORATES_WITH]-(marcus)
MATCH (doc:HealthEntity)-[:AUTHORED_BY|CONTRIBUTED_BY]->(sarah)
MATCH (doc)-[:AUTHORED_BY|CONTRIBUTED_BY]->(marcus)
RETURN
    doc.name AS collaborative_work,
    doc.description AS summary,
    doc.date AS published_date
```

**Why vector search fails:** It has no concept of "collaboration" or "co-authorship".

---

#### Multi-Hop Relationship Query

```cypher
// "Find documents about Arrhythmia written by cardiologists"
MATCH (dept:HealthEntity {name: 'Cardiology Department'})
MATCH (person:HealthEntity)-[:WORKS_IN]->(dept)
WHERE person.role CONTAINS 'Cardiologist'
MATCH (doc:HealthEntity)-[:AUTHORED_BY]->(person)
MATCH (doc)-[:DISCUSSES]->(topic:HealthEntity {name: 'Arrhythmia'})
RETURN
    doc.name AS document,
    person.name AS cardiologist,
    collect(DISTINCT topic.name) AS topics
```

**Why vector search fails:** Requires understanding: department → person → document → topic (4 hops!).

---

### 3. Hybrid Queries (Best of Both Worlds)

#### Semantic Search + Graph Context

```cypher
// "Find treatments similar to beta-blockers, with details about who researches them"
CALL db.index.vector.queryNodes(
    'health_vector_index',
    3,
    $embedding_for_beta_blocker_therapy
) YIELD node, score
WHERE node.node_type = 'Treatment'

// Add graph context
OPTIONAL MATCH (doc:HealthEntity)-[:ANALYZES|STUDIES]->(node)
OPTIONAL MATCH (person:HealthEntity)-[:AUTHORED_BY]-(doc)
OPTIONAL MATCH (person)-[:WORKS_IN]->(org:HealthEntity)

RETURN
    node.name AS treatment,
    score AS similarity,
    collect(DISTINCT doc.name) AS related_research,
    collect(DISTINCT person.name) AS researchers,
    collect(DISTINCT org.name) AS institutions
ORDER BY score DESC
```

**Power:** Combines semantic similarity with organizational context.

---

#### Temporal + Relational + Semantic

```cypher
// "Find recent documents about treatments, written by collaborating researchers"
CALL db.index.vector.queryNodes(
    'health_vector_index',
    5,
    $embedding_for_treatment_protocols
) YIELD node, score
WHERE node.node_type = 'Document'
  AND node.date > '2024-01-01'

MATCH (node)-[:AUTHORED_BY]->(author:HealthEntity)
MATCH (author)-[:COLLABORATES_WITH]-(coauthor:HealthEntity)
MATCH (node)-[:DISCUSSES]->(treatment:HealthEntity)
WHERE treatment.node_type = 'Treatment'

RETURN
    node.name AS document,
    node.date AS published,
    score AS relevance,
    author.name AS lead_author,
    collect(DISTINCT coauthor.name) AS collaborators,
    collect(DISTINCT treatment.name) AS treatments_discussed
ORDER BY node.date DESC, score DESC
```

**Power:** Filters by time, finds collaborations, and ranks by semantic relevance.

---

### 4. Path Queries (Relationship Discovery)

#### Shortest Path Between Concepts

```cypher
// "How is Arrhythmia connected to the Clinical Research Team?"
MATCH path = shortestPath(
    (symptom:HealthEntity {name: 'Arrhythmia'})
    -[*..5]-
    (team:HealthEntity {name: 'Clinical Research Team'})
)
RETURN
    [node IN nodes(path) | node.name] AS connection_path,
    [rel IN relationships(path) | type(rel)] AS relationship_types,
    length(path) AS degrees_of_separation
```

**Use case:** Discover unexpected connections between entities.

---

#### Find All Relationships for an Entity

```cypher
// "What is everything we know about Dr. Sarah Chen?"
MATCH (sarah:HealthEntity {name: 'Dr. Sarah Chen'})
OPTIONAL MATCH (sarah)-[r1]->(related1)
OPTIONAL MATCH (sarah)<-[r2]-(related2)

RETURN
    sarah.name AS person,
    sarah.role AS role,
    collect(DISTINCT {
        direction: 'outgoing',
        relationship: type(r1),
        entity: related1.name,
        type: related1.node_type
    }) AS outgoing_relationships,
    collect(DISTINCT {
        direction: 'incoming',
        relationship: type(r2),
        entity: related2.name,
        type: related2.node_type
    }) AS incoming_relationships
```

**Use case:** Complete 360° view of an entity's context.

---

### 5. Aggregation Queries

#### Most Prolific Authors

```cypher
// "Who has authored or contributed to the most documents?"
MATCH (person:HealthEntity)
WHERE person.node_type = 'Person'
OPTIONAL MATCH (person)<-[:AUTHORED_BY|CONTRIBUTED_BY]-(doc:HealthEntity)
WHERE doc.node_type = 'Document'

RETURN
    person.name AS author,
    person.role AS role,
    count(doc) AS document_count,
    collect(doc.name) AS documents
ORDER BY document_count DESC
```

---

#### Most Researched Topics

```cypher
// "What topics are most frequently discussed in documents?"
MATCH (doc:HealthEntity)-[:DISCUSSES|ANALYZES|FOCUSES_ON]->(topic:HealthEntity)
WHERE doc.node_type = 'Document'

RETURN
    topic.name AS topic,
    topic.node_type AS type,
    count(doc) AS mention_count,
    collect(doc.name) AS mentioned_in_documents
ORDER BY mention_count DESC
```

---

## 🆚 Vector Search vs. Knowledge Graph

| Capability | Pure Vector Search | Neo4j GraphRAG |
|------------|-------------------|----------------|
| Semantic similarity | ✅ Yes | ✅ Yes |
| Find "similar" documents | ✅ Yes | ✅ Yes |
| "Who worked with whom?" | ❌ No | ✅ Yes |
| "What changed between versions?" | ❌ No | ✅ Yes |
| "Find docs by author's department" | ❌ No | ✅ Yes |
| Multi-hop relationships | ❌ No | ✅ Yes |
| Temporal filtering | ⚠️ Limited | ✅ Yes |
| Aggregations (counts, stats) | ⚠️ Limited | ✅ Yes |
| Graph visualization | ❌ No | ✅ Yes |
| ACID transactions | ❌ No | ✅ Yes |

---

## 🎯 Real-World Use Cases

### HealthTech
```cypher
// "Find all clinical trials where Dr. Chen collaborated with
// researchers studying beta-blockers for atrial fibrillation"
MATCH (sarah:HealthEntity {name: 'Dr. Sarah Chen'})
MATCH (sarah)-[:COLLABORATES_WITH]-(colleague)
MATCH (trial:HealthEntity)-[:AUTHORED_BY|CONTRIBUTED_BY]->(colleague)
MATCH (trial)-[:STUDIES|ANALYZES]->(treatment:HealthEntity)
WHERE treatment.name CONTAINS 'Beta-Blocker'
MATCH (trial)-[:FOCUSES_ON]->(condition:HealthEntity {name: 'Atrial Fibrillation'})
RETURN trial, sarah, colleague, treatment, condition
```

### Enterprise Knowledge Management
```cypher
// "What did the Engineering team discuss about API pricing
// with the Product team before the Q2 launch?"
MATCH (eng:HealthEntity {name: 'Engineering Team'})
MATCH (product:HealthEntity {name: 'Product Team'})
MATCH (eng_person:HealthEntity)-[:WORKS_IN]->(eng)
MATCH (prod_person:HealthEntity)-[:WORKS_IN]->(product)
MATCH (doc:HealthEntity)-[:AUTHORED_BY]->(eng_person)
MATCH (doc)-[:CONTRIBUTED_BY]->(prod_person)
MATCH (doc)-[:DISCUSSES]->(topic:HealthEntity)
WHERE topic.name CONTAINS 'API Pricing'
  AND doc.date < '2024-06-01'
RETURN doc, eng_person, prod_person, topic
ORDER BY doc.date
```

---

## 💡 Key Takeaways

1. **Vector search is great for:** "Find similar content"
2. **Knowledge graphs excel at:** "Find content where X relates to Y through Z"
3. **GraphRAG combines both:** Semantic search + relationship understanding

**The Silent Failure Problem:**
- Pure vector search can return semantically similar results that have broken relationships
- Knowledge graphs ensure returned results have valid, verifiable connections
- Neo4j GraphRAG = No more silent failures ✅

---

## 🚀 Try It Yourself

1. Start the local Neo4j instance:
   ```bash
   docker compose up -d
   ```

2. Run the test to populate data:
   ```bash
   cd src && python rag_test.py
   ```

3. Open Neo4j Browser (http://localhost:7474)
   - Username: `neo4j`
   - Password: `test_password_12345`

4. Run any of these queries!

5. Visualize the graph:
   ```cypher
   MATCH (n)-[r]->(m)
   RETURN n, r, m
   LIMIT 100
   ```

---

**Built to demonstrate why Pure Neo4j > Split Stack (Pinecone + Neo4j)**
