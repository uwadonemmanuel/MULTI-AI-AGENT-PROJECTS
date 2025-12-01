# Testing Guide

This project uses pytest for unit testing and coverage reporting.

## Running Tests

### Install Dependencies

```bash
pip install -r requirements.txt
```

### Run All Tests

```bash
pytest
```

### Run Tests with Coverage

```bash
pytest --cov=app --cov=update-env-vars.py --cov-report=html --cov-report=term
```

### Run Specific Test File

```bash
pytest tests/test_api.py
```

### Run Specific Test

```bash
pytest tests/test_api.py::TestAPIEndpoints::test_chat_endpoint_success
```

## Coverage Reports

After running tests with coverage, you'll get:

- **Terminal output**: Shows coverage summary
- **HTML report**: `htmlcov/index.html` - Open in browser for detailed coverage
- **XML report**: `coverage.xml` - Used by SonarQube

### View HTML Coverage Report

```bash
# Generate report
pytest --cov=app --cov=update-env-vars.py --cov-report=html

# Open in browser (macOS)
open htmlcov/index.html

# Open in browser (Linux)
xdg-open htmlcov/index.html
```

## Test Structure

```
tests/
├── __init__.py
├── conftest.py              # Shared fixtures
├── test_ai_agent.py        # Tests for AI agent module
├── test_api.py             # Tests for API endpoints
├── test_logger.py          # Tests for logger module
├── test_main.py            # Tests for main module
└── test_update_env_vars.py # Tests for update-env-vars script
```

## Coverage Requirements

- **Minimum Coverage**: 80%
- **Enforced by**: pytest.ini (`--cov-fail-under=80`)
- **SonarQube**: Also requires 80% coverage on new code

## CI/CD Integration

Tests are automatically run in the Jenkins pipeline:

1. **Run Tests** stage: Executes pytest with coverage
2. **SonarQube Analysis** stage: Uses coverage.xml for analysis

## Writing New Tests

### Test Naming Convention

- Test files: `test_*.py`
- Test classes: `Test*`
- Test functions: `test_*`

### Example Test

```python
def test_example():
    """Test description"""
    result = function_under_test()
    assert result == expected_value
```

### Using Fixtures

```python
def test_with_fixture(mock_env_vars):
    """Test using shared fixture"""
    # mock_env_vars provides mocked environment variables
    pass
```

## Mocking External Dependencies

Tests use mocks for:
- External APIs (Groq, Tavily)
- File system operations
- Environment variables
- Subprocess calls

This ensures:
- Tests run fast
- Tests don't require external services
- Tests are deterministic

## Troubleshooting

### Tests Fail with Import Errors

```bash
# Install in development mode
pip install -e .
```

### Coverage Not Showing

```bash
# Make sure coverage is installed
pip install pytest-cov

# Run with coverage flags
pytest --cov=app --cov-report=html
```

### SonarQube Not Showing Coverage

1. Ensure `coverage.xml` is generated
2. Check SonarQube scanner includes: `-Dsonar.python.coverage.reportPaths=coverage.xml`
3. Verify coverage.xml is in project root

