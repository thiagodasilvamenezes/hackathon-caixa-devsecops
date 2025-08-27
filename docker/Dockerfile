FROM eclipse-temurin:17-jre
WORKDIR /work/app
COPY target/quarkus-app/ ./
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "quarkus-run.jar"]
