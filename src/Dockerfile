FROM node:18-alpine

WORKDIR /app

RUN addgroup -S appgroup && adduser -S appuser -G appgroup && \
    chown appuser:appgroup /app

COPY --chown=appuser:appgroup package*.json ./

USER appuser

RUN npm ci --omit=dev

COPY --chown=appuser:appgroup . .

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -qO- http://localhost:8080/health || exit 1

CMD ["node", "server.js"]
