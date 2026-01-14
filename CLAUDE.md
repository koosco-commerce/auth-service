# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Service Overview

Auth-service handles JWT token generation for the commerce platform. Token validation is performed by `common-security` module in each service.

## Authentication Flow

### Registration (Internal API)
Called by user-service after user creation:
```
user-service -> POST /api/auth -> auth-service
```
- Creates `UserAuth` entity with encrypted password
- Supports providers: `LOCAL`, `KAKAO`

### Login
```
Client -> POST /api/auth/login -> auth-service
         <- Authorization header (access token)
         <- Set-Cookie: refreshToken (httpOnly)
```

## JWT Token Structure

### Access Token Claims
| Claim | Description |
|-------|-------------|
| `sub` | User ID |
| `email` | User email |
| `roles` | List of roles (e.g., `ROLE_USER`, `ROLE_ADMIN`) |
| `type` | `access` |
| `iat` | Issued at timestamp |
| `exp` | Expiration timestamp |

### Refresh Token Claims
| Claim | Description |
|-------|-------------|
| `sub` | User ID |
| `type` | `refresh` |
| `iat` | Issued at timestamp |
| `exp` | Expiration timestamp |

### Token Delivery
- **Access Token**: `Authorization` response header
- **Refresh Token**: `Set-Cookie` header with `httpOnly`, `secure`, `sameSite=Strict`

## API Endpoints

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/api/auth` | Register auth credentials (internal) | No |
| POST | `/api/auth/login` | User login | No |

## Port-Adapter Pattern

### Ports (Application Layer)
| Port | Methods |
|------|---------|
| `AuthPersistPort` | `save(UserAuth)`, `findByEmail(String)` |
| `TokenGeneratorPort` | `generateTokens(userId, email, roles)`, `validateRefreshToken(token)` |

### Adapters (Infrastructure Layer)
| Adapter | Implements | Description |
|---------|------------|-------------|
| `AuthPersistAdapter` | `AuthPersistPort` | JPA repository wrapper |
| `JwtTokenGeneratorAdapter` | `TokenGeneratorPort` | JWT token generation using jjwt |

## Database Schema

### user_auth
| Column | Type | Description |
|--------|------|-------------|
| id | BIGINT | Primary key |
| user_id | BIGINT | Reference to user-service |
| email | VARCHAR(255) | User email |
| provider | VARCHAR(10) | `LOCAL` or `KAKAO` |
| password | VARCHAR(255) | BCrypt encrypted |
| role | VARCHAR(10) | `ROLE_USER` or `ROLE_ADMIN` |
| refresh_token | VARCHAR(500) | Stored refresh token |
| created_at | DATETIME | Creation timestamp |
| updated_at | DATETIME | Last update timestamp |

**Indexes**: `idx_user_auth_user_id`, `idx_user_auth_email`
**Constraints**: `uq_email_provider` (email + provider unique)

### login_history
| Column | Type | Description |
|--------|------|-------------|
| id | BIGINT | Primary key |
| user_id | BIGINT | Reference to user-service |
| ip | VARCHAR(50) | Client IP address |
| user_agent | VARCHAR(500) | Browser user agent |
| login_at | DATETIME | Login timestamp |

## Public Endpoints Configuration

Configured in `AuthPublicEndpointProvider`:
```kotlin
arrayOf(
    "/api/auth",           // Registration
    "/api/auth/login",     // Login
    "/actuator/health/**", // Kubernetes health checks
    "/actuator/info",      // Application info
)
```

## Configuration

JWT settings via `JwtProperties`:
```yaml
jwt:
  secret: ${JWT_SECRET}           # Min 256 bits (32 bytes)
  expiration: 3600                # Access token TTL (seconds)
  refresh-expiration: 604800      # Refresh token TTL (seconds, 7 days)
```

## Dependencies

Requires GitHub Packages authentication for common modules:
- `common-core` - Shared exceptions, annotations, API response wrapper
- `common-security` - JWT validation, security configuration

Set `GH_USER` and `GH_TOKEN` environment variables or configure in `~/.gradle/gradle.properties`:
```properties
gpr.user=your-github-username
gpr.token=your-github-token
```
