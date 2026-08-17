# Gotcare Care Ledger

This is a Salesforce prototype I built to handle person-directed care funding. It manages the full flow from care planning through claim approvals and keeps a complete audit trail of all spending.

I'm using Salesforce's custom objects for the data model, wrote some Apex for the business logic, and built Lightning Web Components for the UI.

## How the data is structured

Each Care Plan can have multiple Funding Allocations, and each allocation can track individual Care Claims. Everything gets logged in a Ledger Entry so we always know where the money went.

```
Care Plan
    └── Funding Allocation
            ├── Care Claim
            └── Ledger Entry
```
