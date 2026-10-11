FROM node:20-alpine
RUN apk add --no-cache python3 py3-pip ffmpeg \
    && python3 -m pip install --no-cache-dir --break-system-packages yt-dlp
WORKDIR /app
COPY package.json server.js ./
ENV PORT=8080
EXPOSE 8080
USER node
CMD ["node", "server.js"]
