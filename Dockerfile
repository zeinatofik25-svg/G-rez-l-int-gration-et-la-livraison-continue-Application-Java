# Stage 1: Build
FROM eclipse-temurin:21-jdk-alpine AS builder

WORKDIR /app

COPY gradlew .
COPY gradle/ gradle/
COPY build.gradle settings.gradle ./
COPY src/ src/

# Fix Windows CRLF line endings before executing
RUN sed -i 's/\r$//' gradlew && chmod +x gradlew && ./gradlew bootWar -x test --no-daemon

# Stage 2: Runtime
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

COPY --from=builder /app/build/libs/workshop-organizer-*.war app.war

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.war"]
