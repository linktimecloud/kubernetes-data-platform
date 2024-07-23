ARG TARGETARCH
FROM --platform=linux/${TARGETARCH} ghcr.io/flant/shell-operator:latest AS builder
RUN apk --no-cache add python3 \
    && python3 -m venv --copies /venv

FROM builder AS pip-package
ENV PATH="/venv/bin:$PATH"

RUN pip install --no-cache --upgrade pip kubernetes==26.1.0 jsonpath==0.82.2 deepdiff==7.0.1


FROM builder AS image
ARG TARGETARCH
ARG VERSION
ENV KDP_ROOT_DIR=${KDP_ROOT_DIR:-.kdp}
ENV PATH="/venv/bin:$PATH"

ADD hooks/* /hooks
ADD cmd/output/${VERSION}/kdp-linux-$TARGETARCH /usr/local/bin/kdp

COPY --from=pip-package /venv /venv


RUN chmod +x /hooks/*  \
    && cd $HOME  \
    && mkdir $KDP_ROOT_DIR