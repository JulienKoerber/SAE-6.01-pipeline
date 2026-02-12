FROM alpine:3.20
LABEL maintainer="SAE DevOps"
CMD ["sh", "-c", "echo Image construite via CI/CD GitLab OK && sleep 3600"]
