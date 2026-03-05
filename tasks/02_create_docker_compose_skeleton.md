---
# Task 02: Create Docker Compose Skeleton

## Goal

Create a basic `docker-compose.yml` file to serve as the foundation for deploying services.

## Dependencies

- 01_setup_repo_structure

## Steps

1. Create an empty `docker-compose.yml` file at the repository root.
2. Add a basic `version` and `services` block to make it a valid (though empty) Docker Compose file.

## Expected Outcome

A valid `docker-compose.yml` file exists at the repository root.

## Verification

```bash
test -f docker-compose.yml
docker compose config
```

## Outputs

- `docker_compose_file`: `docker-compose.yml`
---