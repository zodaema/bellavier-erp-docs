# Roadmap Task 16–30 (Final Unified Version)

## เสา 1 — Stability Phase (Task 16–20)

### Task 16 — System-Wide Integration Tests
- TenantApiBootstrap tests
- CoreApiBootstrap tests
- RateLimiter tests
- JSON envelope consistency

#### Objectives
- Verify the integration and interoperability of core components across the system.
- Ensure that APIs and services behave correctly under typical and edge-case scenarios.

#### Scope
- End-to-end testing of TenantApiBootstrap and CoreApiBootstrap modules.
- Validate the RateLimiter functionality under various load conditions.
- Confirm JSON envelope structures are consistent and compliant.

#### Tools / Frameworks
- PHPUnit for unit and integration tests.
- Postman or similar API testing tools.
- Mock servers or stubs for dependent services.

#### Expected Outputs
- Comprehensive test reports showing pass/fail status.
- Logs capturing any failures or inconsistencies.
- Verified JSON schemas and envelope formats.

#### Success Criteria
- All integration tests pass without critical errors.
- RateLimiter enforces limits as expected.
- JSON envelopes are consistent and validated against schema.

#### Risk / Pitfalls
- Flaky tests due to external dependencies or timing issues.
- Overlooking edge cases in JSON envelope validation.
- RateLimiter tests may fail under simulated high concurrency if not properly configured.

#### Dependencies
- Stable builds of TenantApiBootstrap and CoreApiBootstrap.
- Access to test environment with necessary configurations.

### Task 17 — Real-World Smoke Tests
- CRUD APIs
- WIP / Token APIs
- Operator PWA APIs
- Platform Admin APIs

#### Objectives
- Quickly verify that critical API endpoints and UI components are functioning after deployments.
- Detect major regressions early in the release cycle.

#### Scope
- Basic create, read, update, delete operations on key resources.
- Validation of Work-In-Progress (WIP) and Token API endpoints.
- Smoke tests on Operator Progressive Web App (PWA) and Platform Admin interfaces.

#### Tools / Frameworks
- Automated smoke test scripts using Selenium or Cypress.
- API testing tools like Postman or REST-assured.
- Continuous Integration (CI) pipeline integration.

#### Expected Outputs
- Pass/fail status for all smoke tests.
- Screenshots and logs from UI tests.
- API response validation reports.

#### Success Criteria
- All smoke tests pass in less than 10 minutes.
- No critical failures in core API and UI functionalities.
- Tests run successfully in CI environment.

#### Risk / Pitfalls
- Flaky UI tests due to asynchronous loading or network delays.
- Smoke tests may not cover all edge cases.
- False positives/negatives due to environment inconsistencies.

#### Dependencies
- Up-to-date test data and environment.
- Stable deployment of APIs and UI components.

### Task 18 — Security Review
- Sensitive logs
- CSRF coverage
- Rate limiter bypass
- File permissions
- AI Trace safe mode

#### Objectives
- Identify and mitigate security vulnerabilities in logging, authentication, and file handling.
- Ensure compliance with security best practices and policies.

#### Scope
- Review and sanitize sensitive log data.
- Verify CSRF protections are in place and effective.
- Test for potential rate limiter bypass techniques.
- Audit file system permissions for security compliance.
- Implement safe mode for AI Trace to prevent data leaks.

#### Tools / Frameworks
- Static code analysis tools (e.g., SonarQube).
- Security scanners (e.g., OWASP ZAP).
- Manual penetration testing.
- Log analysis tools.

#### Expected Outputs
- Security audit reports with identified issues and remediation plans.
- Updated configurations for logging and permissions.
- Verified CSRF tokens and rate limiter settings.

#### Success Criteria
- No critical or high-risk vulnerabilities remain.
- Logs do not contain sensitive or PII data.
- CSRF and rate limiting defenses are effective under testing.

#### Risk / Pitfalls
- Overlooking indirect data leaks in logs.
- Misconfigured permissions leading to unauthorized access.
- False sense of security if tests are incomplete.

#### Dependencies
- Access to codebase and deployment environments.
- Collaboration with security team for review and testing.

### Task 19 — Helper → PSR-4 Migration
- permission.php → BGERP\Security
- member_login logic → BGERP\Auth
- bootstrap_migrations.php → BGERP\Migration

#### Objectives
- Refactor legacy helper files into PSR-4 compliant namespaces and classes.
- Improve autoloading, maintainability, and code organization.

#### Scope
- Migrate permission.php to BGERP\Security namespace.
- Move member_login logic to BGERP\Auth namespace.
- Transfer bootstrap_migrations.php to BGERP\Migration namespace.

#### Tools / Frameworks
- Composer autoloader for PSR-4 compliance.
- IDE refactoring tools.
- Static analysis tools to verify namespace correctness.

#### Expected Outputs
- Refactored files with proper namespaces.
- Updated composer.json autoload section.
- All dependent code updated to use new namespaces.

#### Success Criteria
- No runtime errors due to missing classes or incorrect namespaces.
- Autoloading works seamlessly.
- Code passes all tests post-migration.

#### Risk / Pitfalls
- Missing updates in dependent code causing class not found errors.
- Namespace conflicts or incorrect paths.
- Composer autoload cache not refreshed.

#### Dependencies
- Complete understanding of current helper usage.
- Coordination with teams using these helpers.

### Task 20 — Bootstrap Fine-Tuning
- Global JSON Envelope
- Request profiler
- Expanded rate limits
- Bootstrap flags (debug/strict/safe mode)
- Request-scoped context registry

#### Objectives
- Enhance bootstrap process for better observability, configurability, and performance.
- Implement global JSON envelope for consistent API responses.
- Integrate request profiling and expanded rate limiting.

#### Scope
- Develop and apply global JSON envelope wrapper.
- Add request profiler hooks to capture performance metrics.
- Adjust rate limiter thresholds and policies.
- Introduce bootstrap flags for debug, strict, and safe mode.
- Implement context registry scoped to each request lifecycle.

#### Tools / Frameworks
- Custom middleware or bootstrap scripts.
- Profiling tools like Xdebug or Blackfire.
- Configuration management tools.

#### Expected Outputs
- Consistent API response envelopes.
- Detailed request profiling data.
- Configurable rate limiting parameters.
- Documented bootstrap flags and usage.
- Reliable context registry accessible during requests.

#### Success Criteria
- API responses conform to global envelope standard.
- Profiling data is accurate and available.
- Rate limiting behaves as configured.
- Bootstrap flags function correctly.
- Context registry operates without leaks or conflicts.

#### Risk / Pitfalls
- Performance overhead from profiling or envelope wrapping.
- Misconfiguration of rate limits causing service disruption.
- Context leaks across requests.
- Confusion over bootstrap flag effects.

#### Dependencies
- Existing bootstrap infrastructure.
- Monitoring and logging systems integration.

---

## เสา 2 — Performance Phase (Task 21–25)

### Task 21 — Query Optimizer for WIP / Trace / Routing
- Optimize queries in trace_api, dag_token_api, dag_routing_api

#### Objectives
- Improve database query efficiency and reduce latency for critical APIs.
- Enhance overall system throughput and responsiveness.

#### Scope
- Analyze and optimize SQL queries in trace_api.
- Refine queries in dag_token_api and dag_routing_api modules.
- Implement indexing or query restructuring as needed.

#### Tools / Frameworks
- Database profiling tools (e.g., EXPLAIN plans).
- Query analyzers and profilers.
- Performance monitoring dashboards.

#### Expected Outputs
- Optimized SQL queries with reduced execution times.
- Updated schema indexes if applicable.
- Reports documenting before and after performance metrics.

#### Success Criteria
- Noticeable reduction in query execution time.
- No regression in query correctness or data integrity.
- Improved API response times.

#### Risk / Pitfalls
- Over-optimization leading to complex queries that are hard to maintain.
- Missing edge cases causing incorrect data retrieval.
- Indexing overhead impacting write performance.

#### Dependencies
- Access to production or representative database snapshots.
- Collaboration with DBAs.

### Task 22 — Prepared Statement Enforcement
- Enforce executedPrepared() everywhere

#### Objectives
- Ensure all database queries use prepared statements to prevent SQL injection.
- Standardize query execution methods across the codebase.

#### Scope
- Audit all database access code for direct query execution.
- Refactor to use executedPrepared() method consistently.
- Update documentation and coding standards.

#### Tools / Frameworks
- Static code analysis tools.
- Code review and refactoring tools.

#### Expected Outputs
- All queries executed via prepared statements.
- Reduced risk of SQL injection vulnerabilities.
- Consistent query execution patterns.

#### Success Criteria
- Zero direct query executions without prepared statements.
- Passing security scans for SQL injection.
- No regressions in application behavior.

#### Risk / Pitfalls
- Performance impact if prepared statements are misused.
- Missing some queries due to dynamic or generated code.
- Increased complexity in query parameter binding.

#### Dependencies
- Existing executedPrepared() implementation.
- Developer training and awareness.

### Task 23 — Redis Cache Layer
- Cache for static config, metrics, routing snapshots

#### Objectives
- Implement Redis-based caching to reduce database load and improve response times.
- Cache frequently accessed static data and metrics.

#### Scope
- Cache static configuration data.
- Cache runtime metrics and routing snapshots.
- Develop cache invalidation strategies.

#### Tools / Frameworks
- Redis server and clients.
- Cache libraries or custom wrappers.

#### Expected Outputs
- Functional Redis cache layer integrated with application.
- Reduced database queries for cached data.
- Documentation of cache usage and invalidation.

#### Success Criteria
- Measurable performance improvements.
- Cache hit rates within target thresholds.
- No stale data issues affecting correctness.

#### Risk / Pitfalls
- Cache inconsistency due to improper invalidation.
- Redis availability impacting application stability.
- Over-caching causing memory pressure.

#### Dependencies
- Redis infrastructure in place.
- Monitoring for cache health.

### Task 24 — Async Job Runner
- Redis Streams / RabbitMQ workers
- For migration, serial rebuild, token reconciliation

#### Objectives
- Enable asynchronous processing for long-running or batch tasks.
- Improve scalability and responsiveness by offloading work.

#### Scope
- Implement job queues using Redis Streams or RabbitMQ.
- Develop worker processes for migration, serial rebuild, and token reconciliation tasks.
- Ensure reliable job delivery and error handling.

#### Tools / Frameworks
- Redis Streams or RabbitMQ messaging systems.
- Worker frameworks or custom scripts.

#### Expected Outputs
- Fully functional async job runners.
- Job monitoring and retry mechanisms.
- Reduced synchronous processing load.

#### Success Criteria
- Jobs processed reliably and timely.
- System remains responsive under load.
- Errors are logged and retried appropriately.

#### Risk / Pitfalls
- Message loss or duplication.
- Worker crashes or deadlocks.
- Complex error recovery logic.

#### Dependencies
- Messaging infrastructure operational.
- Job definitions and requirements finalized.

### Task 25 — Performance Monitoring Dashboard
- API latency
- Work session throughput
- Error rate
- Token processing metrics

#### Objectives
- Provide real-time visibility into system performance and health.
- Enable proactive issue detection and capacity planning.

#### Scope
- Track and display API latency metrics.
- Monitor work session throughput.
- Collect error rate statistics.
- Measure token processing performance.

#### Tools / Frameworks
- Monitoring tools like Grafana, Prometheus.
- Custom dashboards and alerting.

#### Expected Outputs
- Interactive dashboard with relevant KPIs.
- Alerts for threshold breaches.
- Historical performance data.

#### Success Criteria
- Accurate and timely data collection.
- Useful insights for developers and operators.
- Reduced time to detect and resolve issues.

#### Risk / Pitfalls
- Overhead from excessive metric collection.
- Data inconsistency or gaps.
- Alert fatigue from noisy notifications.

#### Dependencies
- Instrumentation in codebase.
- Monitoring infrastructure setup.

---

## เสา 3 — Developer Experience Phase (Task 26–30)

### Task 26 — Core CLI Tools (CoreCliBootstrap)
Commands:
- erp:migrate
- erp:tenant:create
- erp:serial:rebuild
- erp:org:list

#### Objectives
- Provide developers and administrators with robust command-line tools to manage the ERP system.
- Simplify common operational tasks through standardized CLI commands.

#### Scope
- Implement migration command to apply database schema changes.
- Create tenant creation command with necessary validations.
- Develop serial rebuild command for data integrity.
- Provide organizational listing command.

#### Tools / Frameworks
- Symfony Console or similar CLI framework.
- PHP scripting and command design patterns.

#### Expected Outputs
- Fully functional CLI commands with help and usage documentation.
- Error handling and feedback messages.
- Integration with existing bootstrap and configuration.

#### Success Criteria
- Commands execute successfully with expected results.
- Clear and helpful user feedback.
- Commands tested and documented.

#### Risk / Pitfalls
- Incomplete error handling leading to silent failures.
- Commands causing unintended side effects.
- Lack of input validation.

#### Dependencies
- Stable bootstrap environment.
- Access to configuration and database.

### Task 27 — Standardized Error Code Registry
- TOKEN_403_LOCKED
- SERIAL_500_CORRUPT
- QC_400_INVALID
- ASSIGN_400_NOT_FOUND
- PLAT_401_UNAUTHORIZED

#### Objectives
- Establish a consistent set of error codes for API responses and internal handling.
- Facilitate easier debugging and client-side error processing.

#### Scope
- Define error codes with clear semantics and documentation.
- Integrate error codes into API responses.
- Update client and server code to use standardized codes.

#### Tools / Frameworks
- Error handling libraries or middleware.
- Documentation tools.

#### Expected Outputs
- Centralized error code registry.
- Updated API responses with error codes.
- Developer guidelines for error usage.

#### Success Criteria
- Uniform error codes used across all APIs.
- Improved clarity in error handling.
- Reduced ambiguity for clients.

#### Risk / Pitfalls
- Overlapping or conflicting error codes.
- Inconsistent usage leading to confusion.
- Lack of backward compatibility.

#### Dependencies
- Agreement on error code taxonomy.
- Coordination with client developers.

### Task 28 — Auto-Generate API Docs
- Read from PHPDoc, router metadata, error codes

#### Objectives
- Automate generation of comprehensive API documentation.
- Ensure docs are always up-to-date with codebase changes.

#### Scope
- Parse PHPDoc comments for API methods.
- Extract routing metadata and error code references.
- Generate human-readable documentation in HTML or Markdown.

#### Tools / Frameworks
- Swagger/OpenAPI generators.
- PHPDoc parsers.
- Custom scripts for integration.

#### Expected Outputs
- Auto-generated API documentation site.
- Inclusion of error codes and usage examples.
- Documentation generation as part of CI pipeline.

#### Success Criteria
- Documentation reflects current API state.
- Easy to navigate and understand.
- Minimal manual maintenance required.

#### Risk / Pitfalls
- Incomplete or inconsistent PHPDoc comments.
- Generation errors or missing metadata.
- Documentation lagging behind code changes.

#### Dependencies
- Well-maintained PHPDoc comments.
- Consistent routing metadata standards.

### Task 29 — On-Request Logging (Sensitive-Safe)
- Masked data logging
- Performance markers
- AI-trace integration

#### Objectives
- Enhance request logging to capture useful diagnostics while protecting sensitive data.
- Integrate performance markers and AI tracing for advanced analysis.

#### Scope
- Implement data masking for sensitive fields in logs.
- Add timing and performance markers to request logs.
- Integrate with AI-trace systems for enriched context.

#### Tools / Frameworks
- Logging libraries with masking capabilities.
- Performance profiling tools.
- AI tracing platforms.

#### Expected Outputs
- Logs that balance detail with privacy.
- Performance data embedded in logs.
- Correlated AI-trace logs for requests.

#### Success Criteria
- No sensitive data exposed in logs.
- Performance markers provide actionable insights.
- AI-trace integration works seamlessly.

#### Risk / Pitfalls
- Over-masking obscuring useful information.
- Performance overhead from detailed logging.
- Integration complexity with AI-trace.

#### Dependencies
- Logging configuration standards.
- Access to AI-trace infrastructure.

### Task 30 — API Versioning v1 → v2
- Routing designer v2
- Time-engine v2
- Next-gen work session engine
- AI-driven logic integration

#### Objectives
- Transition APIs from version 1 to version 2 with improved features and architecture.
- Incorporate AI-driven logic and next-gen engines.

#### Scope
- Develop v2 routing designer with enhanced capabilities.
- Upgrade time-engine to v2 with better performance.
- Implement next-generation work session engine.
- Integrate AI-driven decision logic into API workflows.

#### Tools / Frameworks
- API versioning frameworks.
- AI/ML libraries.
- Backend service orchestration.

#### Expected Outputs
- Stable v2 APIs running alongside v1.
- Documentation and migration guides.
- Improved system capabilities and performance.

#### Success Criteria
- Backward compatibility maintained.
- v2 APIs pass all tests and meet SLAs.
- Smooth migration path for clients.

#### Risk / Pitfalls
- Breaking changes causing client disruptions.
- AI logic unpredictability.
- Increased complexity in routing and session management.

#### Dependencies
- Client readiness for v2 adoption.
- AI model validation and monitoring.


⸻

🔮 ต่อจากนี้ควรทำอะไร? (แนะนำแบบ Strategy-Level)

คุณมาถึงจุดที่ “รื้อรากของบ้านทั้งหลังแล้วประกอบกลับใหม่อย่างสมบูรณ์แบบ”
ดังนั้น Step ต่อไปควรแบ่งเป็น 3 เสาหลัก:

⸻

📌 เสา 1 – Stability Phase (Task 16–20)

เป้าหมาย: ทำให้ระบบ “นิ่งแบบ Production พร้อมรบ”

แนะนำ Task ลำดับถัดไป:

Task 16 – System-Wide Integration Tests

สร้าง test cases สำหรับ:
	•	TenantApiBootstrap::init() → auth, org resolution, DB connection
	•	CoreApiBootstrap → platform admin logic
	•	RateLimiter → per-scope behavior
	•	JSON error consistency

Task 17 – Real-World Smoke Tests

ทดสอบทุก endpoint ประเภท:
	•	CRUD (products, materials)
	•	WIP/Token (dag_token_api, trace_api)
	•	Operator actions (pwa_scan_api)
	•	Platform admin actions (serial salts, migrations)

Task 18 – Security Review

ตรวจสอบ:
	•	Directory permission
	•	Log sensitivity
	•	CSRF coverage
	•	Rate limiter bypass
	•	File permission (0600) correctness

Task 19 – Refactor Helpers to PSR-4

ตัว helper เก่า เช่น:
	•	permission.php
	•	bootstrap_migrations.php
	•	member_login (old pattern)

ย้ายเข้าสู่ Namespace:
BGERP\Security / BGERP\Auth / BGERP\Migration

แต่ ไม่เปลี่ยน logic (แค่ย้าย code)

Task 20 – Fine-Tune Bootstrap Config

เช่น:
	•	เพิ่ม global JSON envelope option
	•	ปรับ rate-limit default
	•	เพิ่ม request/response profiler

⸻

📌 เสา 2 – Performance Phase (Task 21–25)

หลังระบบนิ่งแล้ว คุณสามารถ:

Task 21 – Query Optimizer for ERP WIP APIs

ตรวจสอบ query จาก:
	•	trace_api.php
	•	dag_routing_api.php
	•	dag_token_api.php
(BOM, WIP, QC → heavy loading)

Task 22 – Add Prepared Statements Everywhere

เพื่อลด SQL injection risk + improve perf

Task 23 – Add Redis Cache Layer

ใช้สำหรับ:
	•	static config
	•	qc metrics summary
	•	status check pages

Task 24 – Add Async Job Runner (RabbitMQ / Redis Streams)

สำหรับ:
	•	Migration tasks
	•	Serial reconciliations
	•	Heavy QC checks

⸻

📌 เสา 3 – Developer Experience Phase (Task 26–30)

นี่จะทำให้ Bellavier Group ERP กลายเป็น “Product-grade ERP Framework”

Task 26 – Add CLI Tools (CoreCliBootstrap)

เพื่อให้:

php artisan erp:migrate
php erp:tenant:create
php erp:org:list

มาจาก framework เดียวกัน

Task 27 – Standardize Error Codes

ERP + Platform = error code registry (SALT_500, TOKEN_403, QC_401)

Task 28 – Auto-Generate API Docs

อ่านจาก:
	•	PHPDoc
	•	Action routing
	•	Json response

Task 29 – Add On-Request Logging for Critical Paths

แต่ masking sensitive data

Task 30 – Implement API Versioning (v1 / v2)

เพื่อรองรับ feature ใหม่ในอนาคต