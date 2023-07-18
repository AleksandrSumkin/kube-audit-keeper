FROM alpine:latest
RUN apk add --no-cache tini bash
COPY kube-audit-keeper.sh ./
ENTRYPOINT ["/sbin/tini", "-s", "--", "/bin/bash", "/kube-audit-keeper.sh"]