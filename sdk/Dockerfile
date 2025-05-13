FROM node:24-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .

RUN npm install pm2 -g

CMD ["pm2-runtime", "ecosystem.config.cjs"]
