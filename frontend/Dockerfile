# # Etapa 1: build
# FROM node:20 AS builder

# WORKDIR /app
# COPY . .
# RUN npm install
# RUN npm run build

# # Etapa 2: execução
# FROM node:20

# WORKDIR /app
# COPY --from=builder /app ./

# EXPOSE 3000
# CMD ["npm", "start"]

# Etapa 1: build
FROM node:20 AS builder

WORKDIR /app
COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

# Etapa 2: runtime
FROM node:20

WORKDIR /app
COPY --from=builder /app ./

EXPOSE 3000
CMD ["npm", "start"]
