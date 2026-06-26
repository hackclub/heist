FROM node:22-slim

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

RUN npm run build

WORKDIR /app/frontend
RUN npm install && npm run build

WORKDIR /app

RUN mkdir -p /app/data

EXPOSE 3000

CMD ["node", "dist/index.js"]
