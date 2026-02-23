# Architecture

## Overview

CredentialsCheck is a Salesforce DX project targeting the SFDO Community Sprints org. This document describes the high-level structure and key architectural decisions.

## Package Structure

| Directory | Purpose |
|-----------|---------|
| `force-app/main/default/` | All Salesforce metadata - Apex, LWC, objects, flows, etc. |
| `config/` | Scratch org definition files |
| `scripts/` | Developer utility scripts (SOQL queries, anonymous Apex) |

## API Version

Currently targeting **API v65.0**. Update `sourceApiVersion` in `sfdx-project.json` when upgrading.

## Development Model

Source-driven development using Salesforce DX. All changes are tracked as source metadata and deployed via `sf project deploy start`.

## Scratch Org Configuration

See `config/project-scratch-def.json` for scratch org shape. Update this file to add required features or settings for local development.
