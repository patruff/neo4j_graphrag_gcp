#!/usr/bin/env python3
"""
Neo4j GraphRAG Example with Google Vertex AI

This script demonstrates how to use real Vertex AI embeddings and LLM
with Neo4j GraphRAG for production use.

Requirements:
- Google Cloud Project with Vertex AI API enabled
- Service account with Vertex AI permissions
- neo4j-graphrag package installed with google extras:
  pip install neo4j-graphrag[google]

Author: Senior DevOps & AI Engineering Team
Date: 2026-01-20
"""

import os
import logging
from typing import List, Dict, Any

from neo4j import GraphDatabase
from neo4j_graphrag.retrievers import VectorCypherRetriever
from neo4j_graphrag.llm import VertexAILLM
from neo4j_graphrag.generation import GraphRAG
from neo4j_graphrag.embeddings import VertexAIEmbeddings
from vertexai.generative_models import GenerationConfig

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def main():
    """Example showing GraphRAG with Vertex AI."""

    # Configuration
    NEO4J_URI = os.getenv("NEO4J_URI", "bolt://localhost:7687")
    NEO4J_USER = os.getenv("NEO4J_USER", "neo4j")
    NEO4J_PASSWORD = os.getenv("NEO4J_PASSWORD", "test_password_12345")
    INDEX_NAME = "health_vector_index"

    # Google Cloud configuration
    GCP_PROJECT = os.getenv("GCP_PROJECT_ID", "your-project-id")
    GCP_LOCATION = os.getenv("GCP_LOCATION", "us-central1")

    logger.info("Connecting to Neo4j...")
    driver = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASSWORD))

    try:
        # Initialize Vertex AI Embeddings
        # Uses textembedding-gecko for embeddings (768 dimensions)
        logger.info("Initializing Vertex AI Embeddings...")
        embedder = VertexAIEmbeddings(
            model_name="textembedding-gecko@003",
            project=GCP_PROJECT,
            location=GCP_LOCATION
        )

        # Create retrieval query for graph context
        retrieval_query = """
        // Get the matched entity and traverse relationships
        OPTIONAL MATCH (node)-[r1:AUTHORED_BY]->(author)
        OPTIONAL MATCH (node)-[r2:DISCUSSES]->(topic)
        OPTIONAL MATCH (node)-[r3:WORKS_IN]->(org)

        RETURN
            node.name AS entity_name,
            node.node_type AS entity_type,
            node.description AS description,
            score,
            collect(DISTINCT author.name) AS authors,
            collect(DISTINCT topic.name) AS topics,
            collect(DISTINCT org.name) AS organizations
        """

        # Initialize retriever with graph traversal
        logger.info("Initializing Vector Cypher Retriever...")
        retriever = VectorCypherRetriever(
            driver=driver,
            index_name=INDEX_NAME,
            embedder=embedder,
            retrieval_query=retrieval_query
        )

        # Initialize Vertex AI LLM (Gemini)
        logger.info("Initializing Vertex AI LLM (Gemini)...")
        generation_config = GenerationConfig(
            temperature=0.0,
            top_p=0.95,
            top_k=40,
            max_output_tokens=1024,
        )

        llm = VertexAILLM(
            model_name="gemini-1.5-flash",
            generation_config=generation_config,
            project=GCP_PROJECT,
            location=GCP_LOCATION
        )

        # Initialize GraphRAG pipeline
        logger.info("Initializing GraphRAG pipeline...")
        rag = GraphRAG(retriever=retriever, llm=llm)

        # Example queries demonstrating GraphRAG
        queries = [
            "What treatments are used for Arrhythmia?",
            "Who authored documents about beta-blockers?",
            "What did Dr. Sarah Chen work on?",
        ]

        logger.info("\n" + "="*60)
        logger.info("Running GraphRAG Queries with Vertex AI")
        logger.info("="*60)

        for i, query in enumerate(queries, 1):
            logger.info(f"\n[Query {i}] {query}")
            logger.info("-" * 60)

            response = rag.search(
                query_text=query,
                retriever_config={"top_k": 3},
                return_context=True
            )

            logger.info(f"Answer: {response.answer}")
            logger.info(f"\nContext Retrieved ({len(response.retriever_result.items)} items):")
            for item in response.retriever_result.items:
                logger.info(f"  - {item.content[:100]}...")

    finally:
        driver.close()
        logger.info("\n✅ Demo completed")


if __name__ == "__main__":
    # Check prerequisites
    required_env_vars = ["GCP_PROJECT_ID"]
    missing = [var for var in required_env_vars if not os.getenv(var)]

    if missing:
        logger.error(f"Missing required environment variables: {', '.join(missing)}")
        logger.error("Please set GCP_PROJECT_ID environment variable")
        exit(1)

    try:
        import vertexai
        from neo4j_graphrag.embeddings import VertexAIEmbeddings
        from neo4j_graphrag.llm import VertexAILLM
    except ImportError:
        logger.error("Missing required packages. Install with:")
        logger.error("pip install neo4j-graphrag[google]")
        exit(1)

    main()
