# Zezav Cloud Infrastructure

![CI Pipeline](https://github.com/zezav-cz/zezav-bolt/actions/workflows/checks.yml/badge.svg)

## Introduction

Welcome to the **Zezav Cloud Infrastructure** repository. This is a personal project used to manage my slowly growing infrastructure, where I host various services for my personal needs.

## Getting Started & Development

This project utilizes a modern development stack to ensure consistency and reliability:

- **Mise**: Used for tool versioning and task running.
- **Lefthook**: Used for managing Git hooks.
- **Dagger**: Used for CI/CD pipelines.

### Initialization Steps

To get started with development, follow these steps to initialize your environment:

1. Install the required tools using Mise:
   ```bash
   mise install
   ```
2. Install the Ruby dependencies:
   ```bash
   bundle install
   ```
3. Fetch the required Puppet modules (e.g., via the Mise task):
   ```bash
   mise run modules
   ```
4. Install lefthook git hooks
   ```bash
   lefthook install
   ```

### Bolt CLI

When running Bolt commands, it is crucial to always prefix them with `bundle exec bolt`. This ensures that the correct Ruby environment and dependencies are used for execution.

## Repository Structure

Here is a brief overview of the main directories and files in this repository:

- `site/`: Custom Puppet profiles, roles, and modules specific to this infrastructure.
- `plans/`: Bolt plans used for orchestration and task execution.
- `data/`: Hiera data for configuration management and secrets.
- `inventory.yaml`: Target node definitions and connection details.
- `.dagger/`: Dagger CI/CD pipeline definitions.

## Usage

Here are a couple of practical examples of how to run Bolt plans within this project:

**Pinging all nodes:**

```bash
bundle exec bolt plan run zezav_bolt::ping -t all
```

**Provisioning or updating a specific node:**

```bash
bundle exec bolt plan run zezav_bolt::install -t <node>
```

## Disclaimer

Please note that this is a personal project running on fairly limited resources. It is **not** meant to be a highly available (HA) production setup, but rather a functional environment for personal use and experimentation.

## License

This project is licensed under the [Apache License 2.0](LICENSE).
