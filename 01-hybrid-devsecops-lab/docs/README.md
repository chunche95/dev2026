# Documentation Structure - Big Tech Style

This directory contains professional documentation following industry best practices from Google SRE, Netflix, and other Big Tech companies.

---

## 📁 Directory Structure

```
docs/
├── incidents/           # Post-mortem reports for incidents
├── runbooks/           # Operational procedures for common tasks
├── adr/               # Architecture Decision Records
├── scripts/           # Automated remediation scripts
└── README.md          # This file
```

---

## 📋 Document Types

### 1. Incident Reports (`incidents/`)
**Purpose**: Post-mortem documentation of production incidents.

**When to Create**:
- Any P0 or P1 incident
- Service outages or degradations
- Security incidents
- Data loss events

**Template**: [`incidents/TEMPLATE-incident.md`](incidents/TEMPLATE-incident.md)

**Naming Convention**: `INC-YYYY-MM-DD-SHORT-TITLE.md`

**Examples**:
- `INC-2026-01-18-grafana-crashloop.md`

---

### 2. Runbooks (`runbooks/`)
**Purpose**: Step-by-step procedures for diagnosing and resolving common operational issues.

**When to Create**:
- Recurring incidents (same issue > 2 times)
- Complex multi-step procedures
- On-call playbooks
- Disaster recovery procedures

**Template**: [`runbooks/TEMPLATE-runbook.md`](runbooks/TEMPLATE-runbook.md)

**Naming Convention**: `RB-XXX-short-title.md` (sequential numbering)

**Examples**:
- `RB-001-grafana-datasource-conflict.md`
- `RB-002-prometheus-storage-full.md`

---

### 3. Architecture Decision Records (`adr/`)
**Purpose**: Document significant architectural decisions with context and rationale.

**When to Create**:
- Technology selection (databases, frameworks, tools)
- Infrastructure changes (deployment patterns, networking)
- Security architecture decisions
- Data architecture decisions

**Template**: [`adr/TEMPLATE-adr.md`](adr/TEMPLATE-adr.md)

**Naming Convention**: `ADR-XXX-short-title.md` (sequential numbering)

**Examples**:
- `ADR-001-kubernetes-platform-selection.md`
- `ADR-002-observability-stack-design.md`
- `ADR-003-grafana-datasource-default.md`

---

### 4. Scripts (`scripts/`)
**Purpose**: Automated remediation and operational scripts.

**When to Create**:
- Incident fixes that can be automated
- Deployment automation
- Health checks and validation

**Naming Convention**: `action-component-purpose.sh`

**Best Practices**:
- ✅ Include shebang (`#!/bin/bash`)
- ✅ Set error handling (`set -euo pipefail`)
- ✅ Add header comment with metadata
- ✅ Use colored output for readability
- ✅ Include validation and rollback procedures
- ✅ Reference related runbooks/incidents in comments

**Examples**:
- `fix-grafana-datasource-conflict.sh`
- `validate-cluster-health.sh`

---

## 🔗 Document Relationships

Documents should reference each other:

```
Incident Report
    ↓ (references)
Runbook (how to fix)
    ↓ (references)
ADR (why we decided this)
    ↓ (implements)
Script (automation)
```

**Example Workflow**:
1. **Incident occurs** → Create `INC-2026-01-18-grafana-crashloop.md`
2. **Recurring problem** → Create `RB-001-grafana-datasource-conflict.md`
3. **Architectural decision** → Create `ADR-003-grafana-datasource-default.md`
4. **Automation** → Create `fix-grafana-datasource-conflict.sh`

Each document cross-references the others.

---

## ✍️ Writing Guidelines

### General Principles
1. **Be Concise**: Busy engineers scan, don't read
2. **Be Specific**: Include exact commands, not vague instructions
3. **Be Complete**: Someone new should be able to follow without asking
4. **Be Accurate**: Test all commands before documenting

### Incident Reports
- ✅ Include timeline with UTC timestamps
- ✅ Separate symptoms from root cause
- ✅ List action items with owners and due dates
- ✅ Be blameless (focus on systems, not people)

### Runbooks
- ✅ Start with symptoms (how to know you need this runbook)
- ✅ Include copy-paste commands
- ✅ Show expected vs actual output
- ✅ Always include rollback procedure

### ADRs
- ✅ Explain the "why" not just the "what"
- ✅ Document alternatives considered
- ✅ List both pros and cons honestly
- ✅ Include implementation status

---

## 🎯 Severity Levels

| Level | Description | Response Time | Examples |
|-------|-------------|---------------|----------|
| **P0** | Critical outage | 15 min | Complete service down |
| **P1** | Major degradation | 1 hour | Key feature unavailable |
| **P2** | Minor degradation | 4 hours | Performance issue |
| **P3** | Cosmetic issue | 1 day | UI glitch |
| **P4** | Enhancement | 1 week | Feature request |

---

## 📊 Metrics & Reviews

### Document Reviews
- **Incident Reports**: Review within 48h of resolution
- **Runbooks**: Test quarterly, update as needed
- **ADRs**: Review dates specified in each ADR

### Success Metrics
- Mean Time to Resolution (MTTR)
- Incident recurrence rate
- Runbook effectiveness (% incidents resolved without escalation)

---

## 🔍 Finding Documents

### By Incident
```bash
# Find incident by date
ls -l incidents/ | grep "2026-01-18"

# Find by component
grep -l "grafana" incidents/*.md
```

### By Component
```bash
# All grafana-related docs
find . -name "*.md" -exec grep -l "grafana" {} \;
```

### By Status
```bash
# All open incidents
grep -l "Status.*Open" incidents/*.md

# All implemented ADRs
grep -l "Status.*Implemented" adr/*.md
```

---

## 📚 References

### Industry Standards
- [Google SRE Book](https://sre.google/sre-book/table-of-contents/)
- [Google Postmortem Culture](https://sre.google/sre-book/postmortem-culture/)
- [ADR GitHub](https://adr.github.io/)
- [Architectural Decision Records](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)

### Internal Standards
- Code of Conduct: Be blameless
- Documentation Standard: Templates in this directory
- Review Process: All P0/P1 incidents require post-mortem

---

## 🤝 Contributing

1. Use templates for all new documents
2. Cross-reference related documents
3. Get peer review before marking as final
4. Keep metadata up to date
5. Test all commands before documenting

---

**Last Updated**: 2026-01-18  
**Maintained By**: Platform Engineering Team
