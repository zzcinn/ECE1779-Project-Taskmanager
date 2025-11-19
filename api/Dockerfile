FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production || npm i --only=production
COPY app.js ./app.js
COPY public ./public
CMD ["node", "app.js"]
