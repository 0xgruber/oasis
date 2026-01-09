# Security Policy

## Reporting a Vulnerability

**O.A.S.I.S.** is a security-focused project, and we take security vulnerabilities seriously. If you discover a security issue, please report it responsibly.

### How to Report

**DO NOT** open a public GitHub issue for security vulnerabilities.

Instead, please report security vulnerabilities by:

1. **Email**: Send details to the project maintainer at the email associated with the GitHub account [@0xgruber](https://github.com/0xgruber)
2. **GitHub Security Advisories**: Use GitHub's private vulnerability reporting feature at:
   - Navigate to: `https://github.com/0xgruber/oasis/security/advisories/new`

### What to Include

Please provide the following information in your report:

- **Description**: Clear description of the vulnerability
- **Impact**: Potential impact and severity assessment
- **Reproduction Steps**: Detailed steps to reproduce the issue
- **Affected Components**: Which parts of O.A.S.I.S. are affected (e.g., gateway, API service, web portal)
- **Suggested Fix**: If you have ideas on how to fix it (optional)
- **Your Contact Information**: How we can reach you for follow-up

### Response Timeline

- **Acknowledgment**: We aim to acknowledge receipt of your vulnerability report within 48 hours
- **Initial Assessment**: Within 7 days, we will provide an initial assessment of the vulnerability
- **Fix Timeline**: Critical vulnerabilities will be prioritized and addressed as quickly as possible
- **Disclosure**: We follow coordinated disclosure practices and will work with you on appropriate disclosure timing

### Vulnerability Severity Levels

We use the following severity classifications:

- **Critical**: Remote code execution, authentication bypass, data breach affecting multiple tenants
- **High**: Privilege escalation, unauthorized data access within a tenant, denial of service
- **Medium**: Information disclosure, cross-site scripting (XSS), configuration weaknesses
- **Low**: Minor information leaks, edge case bugs with minimal security impact

### Security Best Practices for Contributors

If you're contributing to O.A.S.I.S., please:

- **Never commit secrets**: No API keys, passwords, certificates, or tokens in code
- **Review dependencies**: Check for known vulnerabilities in third-party packages
- **Validate inputs**: All user inputs must be validated and sanitized
- **Use parameterized queries**: Prevent SQL injection by using prepared statements
- **Follow least privilege**: Services should have minimal required permissions
- **Test security controls**: Ensure authentication, authorization, and data isolation work correctly

### Automated Security Scanning

O.A.S.I.S. uses automated security scanning in CI/CD:

- **Trivy**: Container vulnerability scanning
- **Syft + Grype**: SBOM generation and vulnerability detection
- **gitleaks**: Secret detection in commits
- **Dependabot**: Automated dependency updates for known vulnerabilities

All pull requests must pass security scans before merging.

### Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| Phase 1 (dev) | :white_check_mark: |
| Pre-release   | :x:                |

Once we reach a stable release, this table will be updated with supported versions for security patches.

### Security Features in O.A.S.I.S.

O.A.S.I.S. is designed with security as a core principle:

- **Network Segmentation**: Three-subnet architecture (DMZ, Internal, Backend)
- **Defense in Depth**: Multiple layers of security controls
- **Multi-Tenant Isolation**: Table-per-tenant data separation in ClickHouse
- **Authentication & Authorization**: API keys, JWT tokens, RBAC with multiple roles
- **Audit Logging**: Complete audit trail of all configuration changes
- **Encryption in Transit**: mTLS between gateways and backend, TLS for all web traffic
- **Secure Defaults**: Non-root containers, minimal permissions, security headers
- **Input Validation**: All inputs validated at gateway and API layers
- **Rate Limiting**: Protection against denial of service and log flooding attacks

### Scope

The following are **in scope** for vulnerability reports:

- Authentication and authorization bypasses
- Data leakage between tenants (multi-tenancy isolation issues)
- Remote code execution
- SQL injection, command injection, and other injection attacks
- Cross-site scripting (XSS) and cross-site request forgery (CSRF)
- Insecure direct object references (IDOR)
- Security misconfigurations with exploitable impact
- Cryptographic vulnerabilities
- Denial of service (DoS) attacks

The following are **out of scope**:

- Vulnerabilities in third-party dependencies (report to the upstream project)
- Social engineering attacks
- Physical security issues
- Attacks requiring physical access to infrastructure
- Issues in unsupported or pre-release versions
- Theoretical vulnerabilities without proof of concept

### Disclosure Policy

- **Coordinated Disclosure**: We prefer coordinated disclosure where vulnerabilities are publicly disclosed after a fix is available
- **Default Timeline**: We aim to release fixes within 90 days of report
- **Credit**: Security researchers who responsibly disclose vulnerabilities will be credited in release notes (if desired)
- **CVE Assignment**: For significant vulnerabilities, we will request CVE identifiers

### Security Hall of Fame

We will maintain a list of security researchers who have responsibly disclosed vulnerabilities to O.A.S.I.S. (with their permission).

*No entries yet - this project is in early development.*

---

## Security Updates

Security updates will be announced through:

- GitHub Security Advisories
- Release notes for patched versions
- Project README.md updates for critical issues

## Questions?

If you have questions about this security policy, please open a public GitHub issue or contact the maintainer.

---

**Thank you for helping keep O.A.S.I.S. and its users safe!**
