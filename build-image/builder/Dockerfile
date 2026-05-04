FROM docker:27-cli

WORKDIR /app
COPY build-and-run.sh .
RUN chmod +x build-and-run.sh

ENTRYPOINT ["/app/build-and-run.sh"]
