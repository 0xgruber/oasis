## ADDED Requirements

### Requirement: Dashboard Layout
The system SHALL provide a responsive web dashboard for viewing security logs and system status.

#### Scenario: Dashboard access
- **WHEN** a user navigates to the root URL
- **THEN** the system displays the main dashboard
- **AND** shows ingestion rate statistics
- **AND** displays recent log count by severity
- **AND** provides navigation to log search interface

#### Scenario: Responsive design
- **WHEN** the dashboard is viewed on different screen sizes
- **THEN** the layout adapts to mobile, tablet, and desktop screens
- **AND** maintains usability across all breakpoints

### Requirement: Log Viewer Component
The system SHALL provide a table-based interface for viewing and filtering security logs.

#### Scenario: Display recent logs
- **WHEN** a user views the log table
- **THEN** the system displays the 100 most recent logs by default
- **AND** shows timestamp, severity, category, message, and source IP
- **AND** supports sorting by any column

#### Scenario: Pagination
- **WHEN** a user scrolls to the bottom of the log table
- **THEN** the system loads the next 100 logs
- **AND** maintains scroll position
- **AND** indicates loading state during fetch

#### Scenario: Log detail expansion
- **WHEN** a user clicks on a log row
- **THEN** the system expands the row to show full log details
- **AND** displays OCSF normalized fields
- **AND** shows the original raw log

### Requirement: Basic Search Interface
The system SHALL provide a search interface for filtering logs by common criteria.

#### Scenario: Time range filter
- **WHEN** a user selects a time range (last 1h, 24h, 7d, custom)
- **THEN** the system queries logs within that time range
- **AND** updates the log table with results
- **AND** displays the result count

#### Scenario: Severity filter
- **WHEN** a user selects one or more severity levels (info, warning, error, critical)
- **THEN** the system filters logs by selected severities
- **AND** updates the log table in real-time

#### Scenario: Text search
- **WHEN** a user enters text in the search box
- **THEN** the system searches across log message, source IP, and user fields
- **AND** highlights matching text in results
- **AND** supports basic wildcards (* and ?)

#### Scenario: Search reset
- **WHEN** a user clicks "Clear Filters"
- **THEN** the system resets all filters to defaults
- **AND** displays the most recent 100 logs

### Requirement: Authentication UI (Stub)
The system SHALL provide login and authentication interfaces as stubs for Phase 2 implementation.

#### Scenario: Login page
- **WHEN** an unauthenticated user accesses the application
- **THEN** the system displays a login form
- **AND** accepts username and password
- **AND** provides a "Login" button

#### Scenario: Login success (stub)
- **WHEN** a user submits the login form
- **THEN** the system accepts any credentials (Phase 1 stub behavior)
- **AND** redirects to the dashboard
- **AND** stores a session token in localStorage

#### Scenario: Logout
- **WHEN** a user clicks "Logout"
- **THEN** the system clears the session token
- **AND** redirects to the login page

### Requirement: Error Handling and User Feedback
The system SHALL provide clear error messages and loading states.

#### Scenario: API error handling
- **WHEN** an API request fails
- **THEN** the system displays an error toast notification
- **AND** includes a user-friendly error message
- **AND** logs the full error details to console

#### Scenario: Loading states
- **WHEN** data is being fetched from the API
- **THEN** the system displays a loading spinner or skeleton UI
- **AND** disables interactive elements during loading
- **AND** provides a cancel option for long-running queries

#### Scenario: Empty state
- **WHEN** no logs match the current filters
- **THEN** the system displays an "No logs found" message
- **AND** suggests adjusting filters or time range

### Requirement: Performance and Responsiveness
The system SHALL provide a responsive user interface with minimal perceived latency.

#### Scenario: Initial page load
- **WHEN** a user first loads the dashboard
- **THEN** the page renders within 2 seconds
- **AND** displays cached or default data immediately
- **AND** updates with live data asynchronously

#### Scenario: Search responsiveness
- **WHEN** a user applies filters
- **THEN** the UI updates within 500ms
- **AND** debounces rapid filter changes
- **AND** cancels pending requests when filters change

### Requirement: API Client Integration
The system SHALL provide a type-safe API client for communicating with the backend.

#### Scenario: OpenAPI code generation
- **WHEN** the backend OpenAPI specification is updated
- **THEN** the frontend can regenerate TypeScript API client types
- **AND** compile-time type checking catches API mismatches

#### Scenario: Request/response validation
- **WHEN** the frontend makes an API request
- **THEN** request parameters are validated against TypeScript types
- **AND** responses are validated and typed
- **AND** validation errors are caught at development time
