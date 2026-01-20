# Contributing to Neo4j GraphRAG GCP POC

First off, thank you for considering contributing to this project! 🎉

## Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When you create a bug report, include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples** (code snippets, error messages)
- **Describe the behavior you observed** and what you expected
- **Include logs** from `rag_test.py` or Terraform output
- **Specify your environment** (OS, Python version, Terraform version, GCP region)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, include:

- **Use a clear and descriptive title**
- **Provide a detailed description** of the suggested enhancement
- **Explain why this enhancement would be useful**
- **List any similar features** in other projects (if applicable)

### Pull Requests

1. **Fork the repository** and create your branch from `main`
2. **Make your changes** following the coding standards below
3. **Run all tests** locally:
   ```bash
   # Python tests
   cd src
   python rag_test.py

   # Terraform validation
   cd terraform
   terraform fmt -check
   terraform validate
   ```
4. **Update documentation** if needed (README.md, inline comments)
5. **Commit your changes** using clear, descriptive commit messages
6. **Push to your fork** and submit a pull request

## Coding Standards

### Python

- Follow **PEP 8** style guide
- Use **type hints** for all function signatures
- Add **docstrings** for all classes and functions
- Maximum line length: **100 characters**
- Use **f-strings** for string formatting
- Handle exceptions explicitly with try/except blocks

Example:
```python
def create_vector_index(self, index_name: str, dimension: int) -> None:
    """
    Create a vector index in Neo4j.

    Args:
        index_name: Name of the vector index to create
        dimension: Dimensionality of the vectors

    Raises:
        Neo4jError: If index creation fails
    """
    try:
        # Implementation
        pass
    except Neo4jError as e:
        logger.error(f"Failed to create index: {e}")
        raise
```

### Terraform

- Use **terraform fmt** before committing
- All variables must have **descriptions**
- Use **validation blocks** for input validation
- Sensitive variables must be marked `sensitive = true`
- Use **consistent naming**: `resource_name-purpose`
- Add **comments** for complex logic

Example:
```hcl
variable "neo4j_password" {
  description = "Password for Neo4j database access"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.neo4j_password) >= 8
    error_message = "Neo4j password must be at least 8 characters long."
  }
}
```

### Git Commit Messages

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests after the first line

Commit message format:
```
<type>: <subject>

<body>

<footer>
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Example:
```
feat: add support for custom vector dimensions

Implemented configurable vector dimensions in the Neo4jGraphRAG class
to support different embedding models (OpenAI, HuggingFace, etc.).

Closes #42
```

## Testing

All code changes must include appropriate tests:

### Python Tests

- Add test cases to `src/rag_test.py`
- Ensure tests are deterministic (use fixed seeds for random data)
- Tests must pass locally before submitting PR

### Infrastructure Tests

- Run `terraform plan` to verify no unexpected changes
- Test with a clean GCP project when possible
- Document any manual testing steps in the PR description

## Development Setup

1. **Clone your fork**
   ```bash
   git clone https://github.com/YOUR_USERNAME/neo4j_graphrag_gcp.git
   cd neo4j_graphrag_gcp
   ```

2. **Set up Python environment**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install -r src/requirements.txt
   ```

3. **Install Terraform**
   ```bash
   # macOS
   brew install terraform

   # Linux
   wget https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip
   unzip terraform_1.6.6_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```

4. **Set up local Neo4j for testing**
   ```bash
   export NEO4J_PASSWORD="test_password_12345"
   docker compose up -d
   ```

## Project Structure

```
neo4j_graphrag_gcp/
├── .github/
│   └── workflows/          # CI/CD pipelines
├── terraform/              # Infrastructure as Code
│   ├── main.tf            # Main infrastructure
│   ├── variables.tf       # Input variables
│   ├── outputs.tf         # Output values
│   └── cloud-init.yml     # VM initialization
├── src/                   # Application code
│   ├── rag_test.py        # Main test script
│   └── requirements.txt   # Python dependencies
├── docker-compose.yml     # Local development
└── README.md             # Documentation
```

## Questions?

Feel free to:
- Open an issue for discussion
- Reach out to the maintainers
- Check existing documentation

Thank you for contributing! 🙌
