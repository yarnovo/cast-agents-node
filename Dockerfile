# cast-agents-node · AgentRun Custom Container
# 高代码模式 · Node 22 · pi-ai + Express
FROM node:22-slim

WORKDIR /app

# 装依赖 (利用 docker 缓存)
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev || npm install --omit=dev

# 拷源码
COPY code/ ./code/

ENV PORT=9000
ENV NODE_ENV=production
EXPOSE 9000

# AgentRun 高代码要求监听 0.0.0.0:9000
CMD ["node", "code/index.js"]
