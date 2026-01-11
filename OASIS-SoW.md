# **Statement of Work (SoW)**

Project Name: O.A.S.I.S. (OSS AI SIEM Intelligence System)  
Date: January 8, 2026  
Primary Developer: \[User\]  
AI Partner: Gemini

## **1\. Executive Summary**

The objective is to architect and develop an open-source, AI-driven Security Information and Event Management (SIEM) platform. O.A.S.I.S. differentiates itself by leveraging local Large Language Models (LLMs) via the Model Context Protocol (MCP) to provide privacy-centric, intelligent threat analysis without relying on external cloud AI providers. The platform is designed for scalability, capable of running on a single robust workstation (Dev) or scaling across distributed servers (Prod).

## **2\. Project Objectives**

1. **AI-First Design:** Integrate LLMs deeply into the workflow via MCP for natural language search, automated triage, and reporting.  
2. **Resource Efficiency:** Optimize architecture to run effectively on consumer workstation hardware (32GB RAM limit) while maintaining high ingestion rates.  
3. **Open Source Governance:** Establish a strictly governed OSS project with MIT licensing, clear contribution guidelines, and security best practices.  
4. **Modularity:** Decouple storage, ingestion, UI, and AI logic to allow independent scaling.

## **3\. Technical Architecture**

**Development Hardware (The Baseline):**

* **OS:** Pop\!\_OS (Linux)  
* **CPU:** Intel i9-12900k  
* **RAM:** 32GB (Strict constraint for memory management)  
* **Storage:** 2TB NVMe  
* **GPU:** Nvidia RTX 4070 Ti Super (16GB VRAM \- Dedicated to LLM Inference)

**Software Stack:**

* **Repo Structure:** Monorepo (Git).  
* **Frontend:** Next.js / React.  
* **Backend/API:** Python (FastAPI) or Go.  
* **Database Layer:**  
  * *Logs:* ClickHouse (Columnar, high compression).  
  * *Vectors:* Qdrant (Semantic search).  
  * *Application Data:* PostgreSQL (Users, Alerts, Config).  
* **AI/LLM:** Ollama (serving Llama-3/Mistral) \+ Local MCP Server.  
* **Data Standards:** OpenSpec (API definitions), OCSF (Log Normalization).

## **4\. Scope of Work (Functional Requirements)**

### **4.1. Core Infrastructure & Ingestion**

* **Ingestion Module:** Service to accept logs (Syslog, HTTP, JSON).  
* **Normalization:** Implementation of OCSF (Open Cybersecurity Schema Framework) to map disparate log sources to a unified schema.  
* **Data Routing:** Logic to split data streams: raw logs to ClickHouse, semantic embeddings to Qdrant.

### **4.2. Web Frontend & Visualization**

* **SOC Dashboard:** Real-time visualization of ingestion rates, threat levels, and active alerts.  
* **Search Interface:**  
  * *Standard:* Boolean/SQL-like search.  
  * *Semantic:* Natural language search ("Show me failed logins from China") processed via MCP.  
* **Reporting:** Module to generate PDF/HTML reports for executive summaries.

### **4.3. AI Intelligence & MCP**

* **Local MCP Server:** Development of custom tools exposed to the LLM (e.g., tool\_query\_db, tool\_fetch\_threat\_intel).  
* **AI Chat Bot:** An embedded chat interface for analysts to interact with the data.  
* **Automated Analysis:** Background workers that pass high-severity alerts to the LLM for "Pre-triage" and summarization.

### **4.4. Alerting & Operations**

* **Rule Engine:** Detection logic (sigma-compatible preferred) running against the stream or scheduled queries.  
* **Multi-Tenancy:** RBAC (Role-Based Access Control) and logical data separation for supporting multiple accounts/teams.

## **5\. Scope of Work (Governance & Non-Functional)**

### **5.1. Security & Compliance**

* **Hardening:** Containers configured as non-root; AppArmor/Seccomp profiles enabled.  
* **Dependency Management:** Automated SBOM generation (Syft/CycloneDX) and vulnerability scanning (Trivy) in CI.  
* **Secrets Management:** No hardcoded secrets; use of environment variables and Vault/GitHub Secrets.

### **5.2. Development & QA**

* **Testing Strategy:** Implementation of the Testing Pyramid (Unit \-\> Integration \-\> E2E with Cypress).  
* **Mocking:** Creation of mock LLM interfaces for CI/CD to prevent costs and flakiness during testing.  
* **Documentation:** Automated generation of OpenAPI (Swagger) specs and Architecture diagrams (PlantUML/Mermaid).

## **6\. Project Phasing & Milestones**

### **Phase 1: Foundation (Weeks 1-3)**

* **Deliverable:** Repository initialized, Docker Compose environment active (DBs running).  
* **Deliverable:** Basic Ingestion Service running (Log in \-\> Database).  
* **Deliverable:** Governance documents (LICENSE, CONTRIBUTING.md) committed.

### **Phase 2: Visibility (Weeks 4-6)**

* **Deliverable:** API Gateway defined via OpenSpec.  
* **Deliverable:** Web Frontend with Basic Log Table and Authentication (Multi-user stubs).  
* **Deliverable:** Search API (Direct DB queries).

### **Phase 3: The Brain (Weeks 7-10)**

* **Deliverable:** Local MCP Server operational.  
* **Deliverable:** Integration of Nvidia GPU with Docker for Ollama.  
* **Deliverable:** Chatbot UI functional; able to execute basic database queries via natural language.

### **Phase 4: Operations & Polish (Weeks 11-14)**

* **Deliverable:** Alerting Engine and Reporting modules.  
* **Deliverable:** Performance benchmarking (Target: 50k EPS ingestion).  
* **Deliverable:** Full documentation site launch.

## **7\. Out of Scope (For Initial Release)**

* **Cloud Hosting:** While the architecture is scalable, the initial build targets local/on-premise deployment.  
* **Proprietary LLM APIs:** Support for GPT-4/Claude API is deprioritized in favor of Local LLM/Privacy focus.  
* **Legacy Agents:** Building custom endpoint agents (EDR); we assume log shipping is handled by existing tools (like Fluentd/Fluent Bit).

### ---

**Approval**

**Does this Statement of Work accurately reflect the scope and requirements of the O.A.S.I.S. project?** If yes, our next interaction will be to begin Phase 1 setup.