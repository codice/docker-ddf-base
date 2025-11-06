# Generate commands from argbash templates
FROM --platform=$BUILDPLATFORM matejak/argbash:2.7.1-1 AS argbash
# Copy all templates including vendored create-cdm.m4 (eliminates external dependency)
COPY argbash-templates/* /work/
RUN ./build.sh

# Create base for final image
FROM azul/zulu-openjdk-alpine:17-latest AS base
LABEL maintainer=oconnormi
LABEL org.codice.application.type=ddf

ENV ENTRYPOINT_HOME=/opt/entrypoint

RUN mkdir -p $ENTRYPOINT_HOME

# Install Alpine packages (jq now from Alpine repos for multi-arch support)
RUN apk add --no-cache curl openssl gettext bash jq

# Install props tool with multi-architecture support from codice/props fork
ARG TARGETARCH
ARG PROPS_VERSION=0.1.1
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) PROPS_ARCH='amd64' ;; \
        arm64) PROPS_ARCH='arm64' ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac; \
    echo "Installing props v${PROPS_VERSION} for ${TARGETARCH}"; \
    curl -fsSL "https://github.com/codice/props/releases/download/v${PROPS_VERSION}/props_${PROPS_VERSION}_linux_${PROPS_ARCH}" \
        -o /usr/local/bin/props; \
    chmod 755 /usr/local/bin/props; \
    props version || props help

COPY entrypoint/* $ENTRYPOINT_HOME/
COPY --from=argbash /out/cmd/* /usr/local/bin/

## Create test base
#FROM base as test
#RUN apk add --no-cache git
#RUN git clone https://github.com/bats-core/bats-core.git
#RUN ./bats-core/install.sh /usr/local
#
## Run unit level tests
#FROM test as unit-test
#COPY ./argbash-templates/tests/* /tests/
#RUN bats /tests/*.bats
#
## Run integration level tests
#FROM test as integration-test
#COPY ./tests/* /tests/
#RUN bats /tests/*.bats
#
## Create final image
#FROM base

ENTRYPOINT ["/bin/bash", "-c", "$ENTRYPOINT_HOME/entrypoint.sh"]
