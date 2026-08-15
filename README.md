# Gotcare Care Ledger

A Salesforce prototype for person-directed care funding, claim approval, budget validation, and financial auditability.

## Business problem

Care funding needs to be transparent and safe. Coordinators need to see allocated funds, approved spending, submitted claims, remaining balances, and the financial history behind every change.

This prototype models that workflow using Salesforce custom objects, Apex, and Lightning Web Components.

## Data model

Care Plan
    └── Funding Allocation
            ├── Care Claim
            └── Ledger Entry
