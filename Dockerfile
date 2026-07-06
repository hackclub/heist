FROM node:24-slim
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund

COPY . .
RUN npm run build

ENV NODE_ENV=production PORT=3000
EXPOSE 3000
CMD ["node", "build/index.js"]
