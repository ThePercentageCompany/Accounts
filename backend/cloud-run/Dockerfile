FROM node:24-bookworm-slim
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
RUN npx playwright install --with-deps chromium && chmod -R a+rX /ms-playwright
COPY --chown=node:node src ./src
USER node
ENV NODE_ENV=production
EXPOSE 8080
CMD ["node", "src/server.js"]
