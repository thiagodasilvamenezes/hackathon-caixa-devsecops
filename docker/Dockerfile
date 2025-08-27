# Build stage
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build
COPY app/pom.xml ./
# Primeiro build direto (go-offline removido para evitar falha com classificadores); cache de camadas Maven já ajuda
COPY app/src ./src
RUN mvn -q -DskipTests package

# Final image (Temurin 17)
FROM eclipse-temurin:17-jre
WORKDIR /work/app
COPY --from=build /build/target/quarkus-app/ ./
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "quarkus-run.jar"]
