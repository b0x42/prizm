## ADDED Requirements

### Requirement: Error messages SHALL include corrective suggestions where actionable
Error messages displayed to the user SHALL include a brief suggestion for how to resolve the issue when a corrective action is known.

#### Scenario: Invalid URL error includes suggestion
- **WHEN** the user enters an invalid server URL
- **THEN** the error message SHALL suggest including "https://"

#### Scenario: Invalid credentials error includes suggestion
- **WHEN** the user enters wrong email or master password
- **THEN** the error message SHALL suggest checking the email and master password

#### Scenario: Server unreachable error includes suggestion
- **WHEN** the server cannot be reached
- **THEN** the error message SHALL suggest checking the URL and network connection

#### Scenario: Session expired error includes suggestion
- **WHEN** the sync fails due to an expired session
- **THEN** the error message SHALL suggest signing out and signing in again

#### Scenario: Network unavailable error includes suggestion
- **WHEN** there is no internet connection
- **THEN** the error message SHALL suggest checking the network connection
