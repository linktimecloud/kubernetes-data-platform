FROM alpine:3.19.1

WORKDIR /workspace

COPY catalog/ catalog/

CMD ["/bin/sh"]