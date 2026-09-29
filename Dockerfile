# ---------------------------------------------------------------------------
# Stage 1: build the Mule app into a deployable JAR
# ---------------------------------------------------------------------------
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /src
COPY pom.xml .
COPY src ./src
COPY mule-artifact.json .
RUN mvn -B clean package -DskipMunitTests=false

# ---------------------------------------------------------------------------
# Stage 2: runtime image
#
# IMPORTANT: MuleSoft's runtime is proprietary and licensed - it cannot be
# pulled from a public Docker registry. To build this image locally you must
# either:
#   a) Have access to Anypoint's private "Mule EE" base images
#      (docs.mulesoft.com -> "Run Mule in Docker"), and swap the FROM line
#      below for the exact tag Anypoint gives you, e.g.:
#        FROM anypointsupport.docker.scm.mulesoft.com/mule-ee/mule-ee-base:4.6.0
#   b) Or download the Mule EE Standalone runtime .zip from your Anypoint
#      Platform account, place it in this folder as mule-runtime.zip, and
#      use the alternate Dockerfile.selfcontained included in this project,
#      which unpacks it onto a plain eclipse-temurin base image.
#
# Once you're authenticated to MuleSoft's registry (docker login on
# anypointsupport.docker.scm.mulesoft.com), this Dockerfile works as-is.
# ---------------------------------------------------------------------------
FROM anypointsupport.docker.scm.mulesoft.com/mule-ee/mule-ee-base:4.6.0

COPY --from=build /src/target/*.jar /opt/mule/apps/hello-mule-app.jar

ENV http.port=8081
EXPOSE 8081

HEALTHCHECK --interval=15s --timeout=5s --start-period=40s --retries=3 \
  CMD wget -qO- http://localhost:8081/health || exit 1

ENTRYPOINT ["/opt/mule/bin/mule"]
