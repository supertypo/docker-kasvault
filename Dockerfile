##
# builder image
##
FROM node:20-alpine AS builder

ARG REPO_DIR

WORKDIR /work

COPY "$REPO_DIR" .

RUN sed -i 's/error/warn/' .eslintrc.json && \
    sed -i "s/setIsShowDemo(window.location.hostname !== 'kasvault.io')/setIsShowDemo(window.location.hostname === 'localhost')/" app/page.tsx

RUN npm install
RUN npm run build

##
# runtime image
##
FROM node:20-alpine

EXPOSE 3000/tcp

USER 36439:36439

COPY --from=builder /work/package*.json ./
COPY --from=builder /work/next.config.js ./
COPY --from=builder /work/.next ./.next
COPY --from=builder /work/public ./public
COPY --from=builder /work/node_modules ./node_modules

ENTRYPOINT ["npm", "start"]

