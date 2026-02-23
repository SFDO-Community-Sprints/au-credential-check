# credential-check-au

A Salesforce DX project for managing and collecting credentials from volunteers (eg. Working with Childrens Check, Police Check, Drivers License).

Continuing the work of a team at the February 2024 Sprint, this project expanded the original goal of managing security and information checks for multiple people and matching qualifications to roles.

## Background

Work performed at previous sprints:

- Review of Feb 2024 Sydney Sprint, including a detailed process map in Lucid Chart
- Expanded scope beyond Working with Children checks to broader credential management use cases
- Built out data model and permission set structure
- Credential verification process with data points for credential management

## Project Structure

```
credentialscheck/
├── force-app/           # Default package directory - all metadata lives here
│   └── main/default/
├── config/              # Scratch org definition files
├── scripts/             # SOQL and Apex utility scripts
└── docs/                # Project documentation
```

## Prerequisites

- [Salesforce CLI](https://developer.salesforce.com/tools/sfdxcli) v2+
- VS Code with [Salesforce Extensions](https://developer.salesforce.com/tools/vscode/)

## Getting Started

1. Authenticate to your target org:
   ```bash
   sf org login web --alias credential-check-au
   ```

2. Push source to a scratch org:
   ```bash
   sf project deploy start
   ```

3. Open the org:
   ```bash
   sf org open
   ```

## Development Model

This project follows the [source-driven development](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_intro.htm) model using Salesforce DX.

## Documentation

See the `/docs` folder for architecture decisions, implementation notes, and the project todo list.
