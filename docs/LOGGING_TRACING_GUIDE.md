# 로깅 & 분산 트레이싱 가이드

## 📋 개요

이 프로젝트는 구조화된 JSON 로깅과 분산 트레이싱을 지원합니다.

### 주요 기능
- ✅ **JSON 구조화 로깅**: Logstash Encoder를 사용한 JSON 포맷 로그
- ✅ **분산 트레이싱**: Micrometer Tracing + Zipkin을 통한 요청 추적
- ✅ **자동 컨텍스트 전파**: MDC를 통한 trace/span/correlation ID 자동 포함
- ✅ **비동기 로깅**: AsyncAppender를 통한 성능 최적화
- ✅ **프로파일별 설정**: local/dev/prod 환경별 로그 레벨 및 출력 방식

---

## 🏗️ 아키텍처

```
┌─────────────────┐
│ HTTP Request    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Correlation     │ ← 고유 ID 생성 및 MDC 설정
│ ID Filter       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ User Context    │ ← 사용자 정보 MDC에 추가
│ Filter          │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Micrometer      │ ← Trace/Span ID 자동 생성
│ Tracing         │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Logback         │ ← JSON 로그 생성 (모든 컨텍스트 포함)
│ (JSON)          │
└────────┬────────┘
         │
         ├──────────────────┐
         ▼                  ▼
┌─────────────────┐  ┌─────────────────┐
│ Console/File    │  │ Zipkin Server   │
│ (로그 저장)      │  │ (분산 추적)      │
└─────────────────┘  └─────────────────┘
```

---

## 📦 의존성

### Gradle (build.gradle.kts)

```kotlin
dependencies {
    // 로깅
    implementation("net.logstash.logback:logstash-logback-encoder:7.4")

    // 분산 트레이싱
    implementation("io.micrometer:micrometer-tracing-bridge-brave")
    implementation("io.zipkin.reporter2:zipkin-reporter-brave")

    // Actuator (메트릭 및 헬스 체크)
    implementation("org.springframework.boot:spring-boot-starter-actuator")
}
```

---

## ⚙️ 설정

### 1. application.yaml

```yaml
management:
  tracing:
    enabled: true
    sampling:
      probability: 1.0  # 100% 샘플링 (프로덕션: 0.1 권장)
  zipkin:
    tracing:
      endpoint: http://localhost:9411/api/v2/spans

logging:
  pattern:
    level: "%5p [${spring.application.name:},%X{traceId:-},%X{spanId:-}]"
```

### 2. logback-spring.xml

주요 Appender:
- **CONSOLE_JSON**: 콘솔 JSON 출력
- **FILE_JSON**: 파일 JSON 출력 (Rolling)
- **ERROR_FILE**: 에러 전용 파일 출력
- **ASYNC_FILE/ERROR**: 비동기 래퍼 (성능 최적화)

프로파일별 설정:
- **local**: Console만 사용, DEBUG 레벨
- **dev**: Console + File, DEBUG/INFO 레벨
- **prod**: File만 사용, WARN/INFO 레벨

---

## 🔍 로그 컨텍스트 정보

모든 로그에 자동으로 포함되는 정보:

| 필드 | 설명 | 예시 | 출처 |
|------|------|------|------|
| `@timestamp` | 로그 생성 시간 | `2024-01-15T10:30:45.123+0900` | Logback |
| `level` | 로그 레벨 | `INFO`, `ERROR` | Logback |
| `logger` | 로거 이름 | `com.koosco.authservice.api.controller.AuthController` | Logback |
| `message` | 로그 메시지 | `User login successful` | Application |
| `service` | 서비스 이름 | `auth-service` | logback-spring.xml |
| `profile` | 활성 프로파일 | `local`, `dev`, `prod` | Spring |
| **`traceId`** | 분산 추적 ID | `64d8e5c7a1b2f3e4` | Micrometer Tracing |
| **`spanId`** | 현재 작업 ID | `a1b2f3e4` | Micrometer Tracing |
| **`correlationId`** | 요청 고유 ID | `550e8400-e29b-41d4-a716-446655440000` | CorrelationIdFilter |
| **`requestId`** | 요청 ID | (correlationId와 동일) | CorrelationIdFilter |
| `clientIp` | 클라이언트 IP | `192.168.1.100` | CorrelationIdFilter |
| `userId` | 사용자 ID | `user@example.com` | UserContextFilter |

---

## 💡 사용 예시

### 1. 기본 로깅

```kotlin
import org.slf4j.LoggerFactory

class AuthController {
    private val log = LoggerFactory.getLogger(javaClass)

    fun login(request: LoginRequest): TokenResponse {
        log.info("Login attempt for user: {}", request.email)

        try {
            val token = authService.authenticate(request)
            log.info("Login successful for user: {}", request.email)
            return TokenResponse(token)
        } catch (e: AuthenticationException) {
            log.error("Login failed for user: {}", request.email, e)
            throw e
        }
    }
}
```

**출력 예시 (JSON)**:
```json
{
  "@timestamp": "2024-01-15T10:30:45.123+0900",
  "level": "INFO",
  "logger": "com.koosco.authservice.api.controller.AuthController",
  "message": "Login successful for user: user@example.com",
  "service": "auth-service",
  "profile": "local",
  "traceId": "64d8e5c7a1b2f3e4",
  "spanId": "a1b2f3e4",
  "correlationId": "550e8400-e29b-41d4-a716-446655440000",
  "clientIp": "192.168.1.100",
  "userId": "user@example.com"
}
```

### 2. MDC 유틸리티 사용

```kotlin
import com.koosco.authservice.common.logging.MDCUtils

class PaymentService {
    private val log = LoggerFactory.getLogger(javaClass)

    fun processPayment(amount: BigDecimal) {
        val correlationId = MDCUtils.getCorrelationId()
        val userId = MDCUtils.getUserId()

        log.info("Processing payment - amount: {}, correlationId: {}, userId: {}",
            amount, correlationId, userId)
    }
}
```

### 3. 비동기 작업에서 MDC 전파

```kotlin
import com.koosco.authservice.common.logging.MDCUtils
import java.util.concurrent.CompletableFuture

class AsyncService {
    private val log = LoggerFactory.getLogger(javaClass)

    fun asyncOperation() {
        // 방법 1: 수동으로 컨텍스트 관리
        val mdcContext = MDCUtils.captureContext()

        CompletableFuture.supplyAsync {
            MDCUtils.restoreContext(mdcContext)
            try {
                log.info("Async operation with MDC context")
                // 비동기 작업 수행
            } finally {
                MDC.clear()
            }
        }

        // 방법 2: 헬퍼 함수 사용 (권장)
        CompletableFuture.supplyAsync {
            MDCUtils.withMDC {
                log.info("Async operation with automatic MDC context")
                // 비동기 작업 수행
            }
        }
    }
}
```

### 4. 구조화된 로깅

```kotlin
import net.logstash.logback.argument.StructuredArguments.*

class OrderService {
    private val log = LoggerFactory.getLogger(javaClass)

    fun createOrder(order: Order) {
        log.info("Order created",
            keyValue("orderId", order.id),
            keyValue("amount", order.totalAmount),
            keyValue("itemCount", order.items.size)
        )
    }
}
```

**출력 예시**:
```json
{
  "@timestamp": "2024-01-15T10:30:45.123+0900",
  "message": "Order created",
  "orderId": "ORD-12345",
  "amount": 50000,
  "itemCount": 3,
  "traceId": "64d8e5c7a1b2f3e4",
  ...
}
```

---

## 🔗 분산 트레이싱

### Zipkin 서버 실행

```bash
# Docker로 Zipkin 실행
docker run -d -p 9411:9411 openzipkin/zipkin

# Zipkin UI 접속
open http://localhost:9411
```

### Trace ID로 검색

1. Zipkin UI에서 Trace ID 또는 Service Name으로 검색
2. 전체 요청 흐름 시각화
3. 각 서비스별 소요 시간 분석
4. 에러 발생 지점 파악

### 요청 헤더로 Correlation ID 전달

```bash
# 클라이언트에서 Correlation ID 전달
curl -H "X-Correlation-ID: my-custom-id" http://localhost:8080/api/auth/login

# 응답 헤더에서 Correlation ID 확인
HTTP/1.1 200 OK
X-Correlation-ID: my-custom-id
```

---

## 📊 로그 분석 및 모니터링

### ELK Stack 연동 (선택사항)

1. **Filebeat**: 로그 파일 수집
2. **Logstash**: 로그 파싱 및 변환
3. **Elasticsearch**: 로그 저장 및 검색
4. **Kibana**: 로그 시각화 및 대시보드

### 로그 검색 예시

```bash
# Correlation ID로 특정 요청의 모든 로그 검색
grep "550e8400-e29b-41d4-a716-446655440000" logs/auth-service.log

# Trace ID로 분산 추적
grep "traceId\":\"64d8e5c7a1b2f3e4" logs/auth-service.log

# 에러 로그만 확인
grep "\"level\":\"ERROR\"" logs/auth-service.log
```

---

## 🎯 프로덕션 권장 사항

### 1. Sampling Rate 조정

```yaml
management:
  tracing:
    sampling:
      probability: 0.1  # 10% 샘플링 (트래픽에 따라 조정)
```

### 2. 로그 레벨 최적화

```yaml
# prod 프로파일
logging:
  level:
    root: WARN
    com.koosco: INFO
```

### 3. 민감 정보 마스킹

```kotlin
class UserService {
    private val log = LoggerFactory.getLogger(javaClass)

    fun login(email: String, password: String) {
        // ❌ 나쁜 예: 민감 정보 로깅
        log.info("Login attempt - email: {}, password: {}", email, password)

        // ✅ 좋은 예: 민감 정보 제외
        log.info("Login attempt - email: {}", maskEmail(email))
    }

    private fun maskEmail(email: String): String {
        val parts = email.split("@")
        return "${parts[0].take(2)}***@${parts[1]}"
    }
}
```

### 4. 로그 보관 정책

```xml
<!-- logback-spring.xml -->
<rollingPolicy class="ch.qos.logback.core.rolling.SizeAndTimeBasedRollingPolicy">
    <maxHistory>30</maxHistory>      <!-- 30일 보관 -->
    <totalSizeCap>10GB</totalSizeCap> <!-- 최대 10GB -->
</rollingPolicy>
```

---

## 🐛 트러블슈팅

### 1. Trace ID가 로그에 나타나지 않음

**원인**: Micrometer Tracing 의존성 누락

**해결**:
```kotlin
dependencies {
    implementation("io.micrometer:micrometer-tracing-bridge-brave")
    implementation("io.zipkin.reporter2:zipkin-reporter-brave")
}
```

### 2. Zipkin으로 데이터가 전송되지 않음

**원인**: Zipkin 서버 미실행 또는 endpoint 설정 오류

**해결**:
```yaml
management:
  zipkin:
    tracing:
      endpoint: http://localhost:9411/api/v2/spans  # 올바른 endpoint 확인
```

### 3. 로그 파일이 생성되지 않음

**원인**: LOG_PATH 권한 문제

**해결**:
```bash
# 로그 디렉토리 생성 및 권한 부여
mkdir -p ./logs
chmod 755 ./logs
```

### 4. 비동기 작업에서 MDC 값이 사라짐

**원인**: 새로운 스레드에서 MDC 컨텍스트가 전파되지 않음

**해결**: `MDCUtils.withMDC` 사용
```kotlin
CompletableFuture.supplyAsync {
    MDCUtils.withMDC {
        // MDC 컨텍스트가 자동으로 복원됨
        log.info("Async operation")
    }
}
```

---

## 📚 참고 자료

- [Micrometer Tracing Documentation](https://micrometer.io/docs/tracing)
- [Logstash Logback Encoder](https://github.com/logfellow/logstash-logback-encoder)
- [Zipkin Documentation](https://zipkin.io/)
- [Spring Boot Actuator](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html)

---

## 📝 체크리스트

설정 완료 확인:

- [x] logstash-logback-encoder 의존성 추가
- [x] Micrometer Tracing 의존성 추가
- [x] logback-spring.xml 설정
- [x] application.yaml tracing 설정
- [x] CorrelationIdFilter 구현
- [x] UserContextFilter 구현
- [x] MDCUtils 유틸리티 클래스
- [ ] Zipkin 서버 실행 (선택사항)
- [ ] 로그 모니터링 도구 연동 (선택사항)

---

**마지막 업데이트**: 2024-01-15