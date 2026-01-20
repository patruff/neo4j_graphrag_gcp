#!/usr/bin/env python3
"""
Neo4j GraphRAG Round-Trip Verification Script

This script demonstrates a complete "Pure Neo4j" architecture for GraphRAG,
addressing silent failures by combining vector search with graph relationships.

Author: Senior DevOps & AI Engineering Team
Date: 2026-01-20
"""

import json
import logging
import os
import sys
import time
from dataclasses import dataclass
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime

import numpy as np
from neo4j import GraphDatabase, Driver
from neo4j.exceptions import ServiceUnavailable, AuthError, Neo4jError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


@dataclass
class HealthTechDocument:
    """Represents a health tech document with semantic embedding."""
    node_type: str
    name: str
    description: str
    embedding: List[float]
    properties: Dict[str, Any]


@dataclass
class TestResult:
    """Test result data structure."""
    test_name: str
    status: str  # "PASS" or "FAIL"
    latency_ms: float
    details: str
    timestamp: str


class Neo4jGraphRAG:
    """
    Production-ready Neo4j GraphRAG client with vector search capabilities.

    This class implements:
    - Connection pooling and retry logic
    - Vector index creation and management
    - Graph data ingestion with relationships
    - Hybrid vector + graph search
    - Data consistency verification
    """

    VECTOR_DIMENSION = 1536  # OpenAI ada-002 dimension
    INDEX_NAME = "health_vector_index"

    def __init__(
        self,
        uri: str,
        username: str,
        password: str,
        max_connection_lifetime: int = 3600,
        max_connection_pool_size: int = 50
    ):
        """Initialize Neo4j connection with production settings."""
        self.uri = uri
        self.username = username
        self.password = password

        try:
            self.driver: Driver = GraphDatabase.driver(
                uri,
                auth=(username, password),
                max_connection_lifetime=max_connection_lifetime,
                max_connection_pool_size=max_connection_pool_size,
                connection_timeout=30,
                max_retry_time=15
            )
            logger.info(f"✓ Connected to Neo4j at {uri}")
        except (ServiceUnavailable, AuthError) as e:
            logger.error(f"✗ Failed to connect to Neo4j: {e}")
            raise

    def close(self) -> None:
        """Close the driver connection."""
        if self.driver:
            self.driver.close()
            logger.info("✓ Neo4j connection closed")

    def verify_connection(self) -> bool:
        """Verify database connectivity."""
        try:
            with self.driver.session() as session:
                result = session.run("RETURN 1 AS test")
                record = result.single()
                return record["test"] == 1
        except Exception as e:
            logger.error(f"Connection verification failed: {e}")
            return False

    def clear_database(self) -> None:
        """Clear all nodes and relationships (use with caution)."""
        with self.driver.session() as session:
            # Drop existing vector index if it exists
            try:
                session.run(f"DROP INDEX {self.INDEX_NAME} IF EXISTS")
                logger.info(f"✓ Dropped existing index: {self.INDEX_NAME}")
            except Neo4jError as e:
                logger.warning(f"Index drop warning: {e}")

            # Delete all nodes and relationships
            session.run("MATCH (n) DETACH DELETE n")
            logger.info("✓ Database cleared")

    def create_vector_index(self) -> None:
        """Create vector index for similarity search."""
        create_index_query = f"""
        CREATE VECTOR INDEX {self.INDEX_NAME} IF NOT EXISTS
        FOR (n:HealthEntity)
        ON n.embedding
        OPTIONS {{
            indexConfig: {{
                `vector.dimensions`: {self.VECTOR_DIMENSION},
                `vector.similarity_function`: 'cosine'
            }}
        }}
        """

        with self.driver.session() as session:
            try:
                session.run(create_index_query)
                logger.info(f"✓ Created vector index: {self.INDEX_NAME}")

                # Wait for index to come online
                self._wait_for_index_online()

            except Neo4jError as e:
                logger.error(f"Failed to create vector index: {e}")
                raise

    def _wait_for_index_online(self, timeout: int = 60) -> None:
        """Wait for vector index to be online."""
        start_time = time.time()

        while time.time() - start_time < timeout:
            with self.driver.session() as session:
                result = session.run(
                    f"SHOW INDEXES YIELD name, state WHERE name = '{self.INDEX_NAME}' RETURN state"
                )
                record = result.single()

                if record and record["state"] == "ONLINE":
                    logger.info(f"✓ Index {self.INDEX_NAME} is ONLINE")
                    return

                time.sleep(2)

        raise TimeoutError(f"Index {self.INDEX_NAME} did not come online within {timeout}s")

    def insert_health_documents(self, documents: List[HealthTechDocument]) -> None:
        """Insert health tech documents with embeddings."""
        insert_query = """
        UNWIND $docs AS doc
        CREATE (n:HealthEntity)
        SET n.node_type = doc.node_type,
            n.name = doc.name,
            n.description = doc.description,
            n.embedding = doc.embedding,
            n.created_at = datetime(),
            n += doc.properties
        RETURN n.name AS name
        """

        docs_data = [
            {
                "node_type": doc.node_type,
                "name": doc.name,
                "description": doc.description,
                "embedding": doc.embedding,
                "properties": doc.properties
            }
            for doc in documents
        ]

        with self.driver.session() as session:
            result = session.run(insert_query, docs=docs_data)
            inserted_count = len(list(result))
            logger.info(f"✓ Inserted {inserted_count} health documents")

    def create_relationships(self, relationships: List[Tuple[str, str, str]]) -> None:
        """
        Create relationships between nodes.

        Args:
            relationships: List of (source_name, relationship_type, target_name)
        """
        create_rel_query = """
        UNWIND $rels AS rel
        MATCH (source:HealthEntity {name: rel.source})
        MATCH (target:HealthEntity {name: rel.target})
        CALL apoc.create.relationship(source, rel.type, {}, target) YIELD rel AS relationship
        RETURN count(relationship) AS created
        """

        # Fallback without APOC
        create_rel_query_fallback = """
        UNWIND $rels AS rel
        MATCH (source:HealthEntity {name: rel.source})
        MATCH (target:HealthEntity {name: rel.target})
        CREATE (source)-[r:RELATED_TO {type: rel.type}]->(target)
        RETURN count(r) AS created
        """

        rels_data = [
            {"source": src, "type": rel_type, "target": tgt}
            for src, rel_type, tgt in relationships
        ]

        with self.driver.session() as session:
            try:
                # Try with dynamic relationship type first (requires APOC)
                result = session.run(create_rel_query, rels=rels_data)
                count = result.single()["created"]
                logger.info(f"✓ Created {count} relationships")
            except Neo4jError:
                # Fallback to static relationship type
                result = session.run(create_rel_query_fallback, rels=rels_data)
                count = result.single()["created"]
                logger.info(f"✓ Created {count} relationships (fallback mode)")

    def vector_search_with_graph(
        self,
        query_embedding: List[float],
        top_k: int = 3
    ) -> List[Dict[str, Any]]:
        """
        Perform vector similarity search with graph relationship traversal.

        This is the core "GraphRAG" functionality that combines:
        1. Vector similarity search
        2. Graph relationship traversal
        """
        search_query = f"""
        CALL db.index.vector.queryNodes(
            '{self.INDEX_NAME}',
            $top_k,
            $query_vector
        ) YIELD node, score

        OPTIONAL MATCH (node)-[r]->(related:HealthEntity)

        RETURN
            node.name AS name,
            node.node_type AS node_type,
            node.description AS description,
            score,
            collect({{
                type: type(r),
                target_name: related.name,
                target_type: related.node_type
            }}) AS relationships
        ORDER BY score DESC
        """

        with self.driver.session() as session:
            result = session.run(
                search_query,
                query_vector=query_embedding,
                top_k=top_k
            )

            results = []
            for record in result:
                results.append({
                    "name": record["name"],
                    "node_type": record["node_type"],
                    "description": record["description"],
                    "similarity_score": record["score"],
                    "relationships": [
                        rel for rel in record["relationships"]
                        if rel["target_name"] is not None
                    ]
                })

            return results


def generate_mock_embedding(seed: int, dimension: int = 1536) -> List[float]:
    """Generate a deterministic mock embedding for testing."""
    np.random.seed(seed)
    embedding = np.random.randn(dimension).astype(float)
    # Normalize to unit vector
    norm = np.linalg.norm(embedding)
    normalized = (embedding / norm).tolist()
    return normalized


def create_sample_health_data() -> Tuple[List[HealthTechDocument], List[Tuple[str, str, str]]]:
    """Create sample health tech documents and relationships."""

    documents = [
        HealthTechDocument(
            node_type="Symptom",
            name="Arrhythmia",
            description="Irregular heartbeat characterized by abnormal heart rhythm patterns",
            embedding=generate_mock_embedding(seed=42),
            properties={
                "severity": "high",
                "category": "cardiovascular",
                "icd10_code": "I49.9"
            }
        ),
        HealthTechDocument(
            node_type="Drug",
            name="Beta-Blocker",
            description="Medication that reduces heart rate and blood pressure by blocking adrenaline effects",
            embedding=generate_mock_embedding(seed=43),
            properties={
                "drug_class": "cardiovascular",
                "administration": "oral",
                "fda_approved": True
            }
        ),
        HealthTechDocument(
            node_type="Diagnosis",
            name="Atrial Fibrillation",
            description="Specific type of arrhythmia involving rapid, irregular atrial contractions",
            embedding=generate_mock_embedding(seed=44),
            properties={
                "condition_type": "chronic",
                "prevalence": "common",
                "risk_level": "moderate"
            }
        )
    ]

    relationships = [
        ("Arrhythmia", "TREATED_BY", "Beta-Blocker"),
        ("Arrhythmia", "MANIFESTS_AS", "Atrial Fibrillation"),
        ("Atrial Fibrillation", "TREATED_BY", "Beta-Blocker")
    ]

    return documents, relationships


def run_graphrag_test(neo4j_client: Neo4jGraphRAG) -> List[TestResult]:
    """Execute the complete GraphRAG round-trip test."""
    results: List[TestResult] = []

    # Test 1: Connection Verification
    logger.info("\n" + "="*60)
    logger.info("TEST 1: Connection Verification")
    logger.info("="*60)
    start_time = time.time()

    try:
        connection_ok = neo4j_client.verify_connection()
        latency = (time.time() - start_time) * 1000

        if connection_ok:
            results.append(TestResult(
                test_name="Connection Verification",
                status="PASS",
                latency_ms=round(latency, 2),
                details="Successfully connected to Neo4j database",
                timestamp=datetime.utcnow().isoformat()
            ))
            logger.info(f"✓ PASS ({latency:.2f}ms)")
        else:
            raise Exception("Connection verification returned False")

    except Exception as e:
        latency = (time.time() - start_time) * 1000
        results.append(TestResult(
            test_name="Connection Verification",
            status="FAIL",
            latency_ms=round(latency, 2),
            details=f"Connection failed: {str(e)}",
            timestamp=datetime.utcnow().isoformat()
        ))
        logger.error(f"✗ FAIL: {e}")
        return results  # Early exit on connection failure

    # Test 2: Database Initialization
    logger.info("\n" + "="*60)
    logger.info("TEST 2: Database Initialization")
    logger.info("="*60)
    start_time = time.time()

    try:
        neo4j_client.clear_database()
        neo4j_client.create_vector_index()
        latency = (time.time() - start_time) * 1000

        results.append(TestResult(
            test_name="Database Initialization",
            status="PASS",
            latency_ms=round(latency, 2),
            details="Database cleared and vector index created",
            timestamp=datetime.utcnow().isoformat()
        ))
        logger.info(f"✓ PASS ({latency:.2f}ms)")

    except Exception as e:
        latency = (time.time() - start_time) * 1000
        results.append(TestResult(
            test_name="Database Initialization",
            status="FAIL",
            latency_ms=round(latency, 2),
            details=f"Initialization failed: {str(e)}",
            timestamp=datetime.utcnow().isoformat()
        ))
        logger.error(f"✗ FAIL: {e}")
        return results

    # Test 3: Data Ingestion
    logger.info("\n" + "="*60)
    logger.info("TEST 3: Data Ingestion")
    logger.info("="*60)
    start_time = time.time()

    try:
        documents, relationships = create_sample_health_data()
        neo4j_client.insert_health_documents(documents)
        neo4j_client.create_relationships(relationships)
        latency = (time.time() - start_time) * 1000

        results.append(TestResult(
            test_name="Data Ingestion",
            status="PASS",
            latency_ms=round(latency, 2),
            details=f"Ingested {len(documents)} documents with {len(relationships)} relationships",
            timestamp=datetime.utcnow().isoformat()
        ))
        logger.info(f"✓ PASS ({latency:.2f}ms)")

    except Exception as e:
        latency = (time.time() - start_time) * 1000
        results.append(TestResult(
            test_name="Data Ingestion",
            status="FAIL",
            latency_ms=round(latency, 2),
            details=f"Ingestion failed: {str(e)}",
            timestamp=datetime.utcnow().isoformat()
        ))
        logger.error(f"✗ FAIL: {e}")
        return results

    # Test 4: Vector Search with Graph Traversal
    logger.info("\n" + "="*60)
    logger.info("TEST 4: Hybrid Vector + Graph Search")
    logger.info("="*60)
    start_time = time.time()

    try:
        # Use the Arrhythmia embedding to search
        query_embedding = generate_mock_embedding(seed=42)
        search_results = neo4j_client.vector_search_with_graph(query_embedding, top_k=3)
        latency = (time.time() - start_time) * 1000

        logger.info(f"\nSearch Results ({len(search_results)} found):")
        for idx, result in enumerate(search_results, 1):
            logger.info(f"\n  [{idx}] {result['name']} ({result['node_type']})")
            logger.info(f"      Similarity Score: {result['similarity_score']:.4f}")
            logger.info(f"      Description: {result['description']}")
            if result['relationships']:
                logger.info(f"      Relationships:")
                for rel in result['relationships']:
                    logger.info(f"        → {rel['type']} → {rel['target_name']} ({rel['target_type']})")

        # Verify results
        if len(search_results) > 0:
            top_result = search_results[0]
            # The query embedding is from Arrhythmia, so it should be the top match
            is_correct_match = top_result['name'] == "Arrhythmia"
            has_relationships = len(top_result['relationships']) > 0

            if is_correct_match and has_relationships:
                results.append(TestResult(
                    test_name="Hybrid Vector + Graph Search",
                    status="PASS",
                    latency_ms=round(latency, 2),
                    details=f"Found correct match '{top_result['name']}' with {len(top_result['relationships'])} graph relationships",
                    timestamp=datetime.utcnow().isoformat()
                ))
                logger.info(f"\n✓ PASS ({latency:.2f}ms)")
            else:
                raise Exception(f"Unexpected top result: {top_result['name']} (expected: Arrhythmia) or missing relationships")
        else:
            raise Exception("No search results returned")

    except Exception as e:
        latency = (time.time() - start_time) * 1000
        results.append(TestResult(
            test_name="Hybrid Vector + Graph Search",
            status="FAIL",
            latency_ms=round(latency, 2),
            details=f"Search failed: {str(e)}",
            timestamp=datetime.utcnow().isoformat()
        ))
        logger.error(f"✗ FAIL: {e}")

    # Test 5: Data Consistency Verification
    logger.info("\n" + "="*60)
    logger.info("TEST 5: Data Consistency Verification")
    logger.info("="*60)
    start_time = time.time()

    try:
        with neo4j_client.driver.session() as session:
            # Verify node count
            node_count = session.run("MATCH (n:HealthEntity) RETURN count(n) AS count").single()["count"]

            # Verify relationship count
            rel_count = session.run("MATCH ()-[r]->() RETURN count(r) AS count").single()["count"]

            # Verify all nodes have embeddings
            nodes_with_embeddings = session.run(
                "MATCH (n:HealthEntity) WHERE n.embedding IS NOT NULL RETURN count(n) AS count"
            ).single()["count"]

            latency = (time.time() - start_time) * 1000

            expected_nodes = 3
            expected_rels = 3

            if node_count == expected_nodes and rel_count == expected_rels and nodes_with_embeddings == expected_nodes:
                results.append(TestResult(
                    test_name="Data Consistency Verification",
                    status="PASS",
                    latency_ms=round(latency, 2),
                    details=f"Verified {node_count} nodes, {rel_count} relationships, all with embeddings",
                    timestamp=datetime.utcnow().isoformat()
                ))
                logger.info(f"✓ PASS ({latency:.2f}ms)")
            else:
                raise Exception(
                    f"Data inconsistency: Expected {expected_nodes} nodes, {expected_rels} rels, "
                    f"got {node_count} nodes, {rel_count} rels, {nodes_with_embeddings} with embeddings"
                )

    except Exception as e:
        latency = (time.time() - start_time) * 1000
        results.append(TestResult(
            test_name="Data Consistency Verification",
            status="FAIL",
            latency_ms=round(latency, 2),
            details=f"Verification failed: {str(e)}",
            timestamp=datetime.utcnow().isoformat()
        ))
        logger.error(f"✗ FAIL: {e}")

    return results


def generate_markdown_table(results: List[TestResult]) -> str:
    """Generate a markdown table from test results."""

    # Calculate summary stats
    total_tests = len(results)
    passed_tests = sum(1 for r in results if r.status == "PASS")
    failed_tests = total_tests - passed_tests
    avg_latency = sum(r.latency_ms for r in results) / total_tests if total_tests > 0 else 0

    # Build markdown
    md = []
    md.append("## 🧪 Test Results\n")
    md.append(f"**Test Run:** {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}\n")
    md.append(f"**Summary:** {passed_tests}/{total_tests} tests passed | Avg Latency: {avg_latency:.2f}ms\n")

    if passed_tests == total_tests:
        md.append("**Status:** ✅ All tests passed!\n")
    else:
        md.append(f"**Status:** ❌ {failed_tests} test(s) failed\n")

    md.append("\n| Test Name | Status | Latency (ms) | Details |")
    md.append("\n|-----------|--------|--------------|---------|")

    for result in results:
        status_icon = "✅" if result.status == "PASS" else "❌"
        md.append(f"\n| {result.test_name} | {status_icon} {result.status} | {result.latency_ms} | {result.details} |")

    return "".join(md)


def main():
    """Main execution function."""
    logger.info("="*60)
    logger.info("Neo4j GraphRAG Round-Trip Verification")
    logger.info("="*60)

    # Get configuration from environment
    neo4j_uri = os.getenv("NEO4J_URI", "bolt://localhost:7687")
    neo4j_user = os.getenv("NEO4J_USER", "neo4j")
    neo4j_password = os.getenv("NEO4J_PASSWORD", "test_password_12345")

    logger.info(f"Connecting to: {neo4j_uri}")
    logger.info(f"Username: {neo4j_user}")

    # Initialize client
    try:
        client = Neo4jGraphRAG(
            uri=neo4j_uri,
            username=neo4j_user,
            password=neo4j_password
        )
    except Exception as e:
        logger.error(f"Failed to initialize Neo4j client: {e}")
        sys.exit(1)

    # Run tests
    try:
        test_results = run_graphrag_test(client)
    except Exception as e:
        logger.error(f"Test execution failed: {e}")
        sys.exit(1)
    finally:
        client.close()

    # Generate and output results
    logger.info("\n" + "="*60)
    logger.info("GENERATING TEST REPORT")
    logger.info("="*60 + "\n")

    markdown_table = generate_markdown_table(test_results)
    print("\n" + markdown_table)

    # Write to file for CI/CD consumption
    output_file = os.getenv("TEST_RESULTS_FILE", "test_results.md")
    with open(output_file, "w") as f:
        f.write(markdown_table)

    logger.info(f"\n✓ Test results written to: {output_file}")

    # Exit with appropriate code
    all_passed = all(r.status == "PASS" for r in test_results)
    sys.exit(0 if all_passed else 1)


if __name__ == "__main__":
    main()
