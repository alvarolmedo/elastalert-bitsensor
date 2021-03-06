ARG ELASTALERT_HOME=/opt/elastalert

FROM alpine:latest as py-ea
ARG ELASTALERT_VERSION=os-0.0.1
ENV ELASTALERT_VERSION=${ELASTALERT_VERSION}
# URL from which to download Elastalert.
ARG ELASTALERT_URL=https://github.com/alvarolmedo/elastalert/archive/$ELASTALERT_VERSION.zip
ENV ELASTALERT_URL=${ELASTALERT_URL}
# Elastalert home directory full path.
ARG ELASTALERT_HOME

WORKDIR /opt

RUN apk add --update --no-cache ca-certificates openssl-dev openssl python2-dev python2 py2-pip py2-yaml libffi-dev gcc musl-dev wget && \
# Download and unpack Elastalert.
    wget -O elastalert.zip "${ELASTALERT_URL}" && \
    unzip elastalert.zip && \
    rm elastalert.zip && \
    mv e* "${ELASTALERT_HOME}"

WORKDIR "${ELASTALERT_HOME}"

# Install Elastalert.
# see: https://github.com/Yelp/elastalert/issues/1654
RUN sed -i 's/jira>=1.0.10/jira>=1.0.10,<1.0.15/g' setup.py && \
    pip install -r requirements.txt && \
    python setup.py install

FROM node:alpine
LABEL maintainer="BitSensor <dev@bitsensor.io>"
# Set timezone for this container
ENV TZ Etc/UTC
# Elastalert home directory full path.
ARG ELASTALERT_HOME

RUN apk add --update --no-cache curl tzdata python2 make libmagic

COPY --from=py-ea /usr/lib/python2.7/site-packages /usr/lib/python2.7/site-packages
COPY --from=py-ea "${ELASTALERT_HOME}" "${ELASTALERT_HOME}"
COPY --from=py-ea /usr/bin/elastalert* /usr/bin/

WORKDIR /opt/elastalert-server
COPY . /opt/elastalert-server

RUN npm install --production --quiet
COPY config/elastalert.yaml "${ELASTALERT_HOME}"/config.yaml
COPY config/elastalert-test.yaml "${ELASTALERT_HOME}"/config-test.yaml
COPY config/config.json config/config.json
RUN sed -i "s|ELASTALERT_HOME|${ELASTALERT_HOME}|" config/config.json
COPY rule_templates/ "${ELASTALERT_HOME}"/rule_templates
COPY elastalert_modules/ "${ELASTALERT_HOME}"/elastalert_modules

EXPOSE 3030
ENTRYPOINT ["npm", "start"]
