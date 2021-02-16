#
# Build the frontend.
#
FROM node:12.18 as dashboard-builder

WORKDIR /usr/src/app

COPY dashboard ./
COPY .git ./

RUN yarn install && yarn run prod
RUN rm -rf .git

#
# Build the server.
#
FROM alpine:3.12 as server-builder

WORKDIR /build

RUN apk upgrade --update-cache --available && \
    apk add ghc \
            alpine-sdk \
            gmp-dev \
            libffi \
            libffi-dev \
            musl-dev \
            zlib-dev \
            ncurses-dev \
            postgresql-dev \
            cabal \
            ca-certificates && \
            cabal update

COPY UNLICENSE      ./
COPY app/           ./app
COPY README.md      ./
COPY hakatime.cabal ./
COPY cabal.project  ./
COPY src/           ./src
COPY sql/           ./sql
COPY test/          ./test
COPY tools/         ./tools

RUN cabal build -j2 --dependencies-only all

RUN cabal build -j2 exe:hakatime && \
    mkdir -p /app/bin                && \
    cp /build/dist-newstyle/build/*-linux/ghc-*/hakatime-*/x/hakatime/opt/build/hakatime/hakatime /app/bin/hakatime

FROM alpine:3.12

RUN apk add --no-cache \
        libffi-dev \
        bash \
        gmp-dev \
        zlib-dev \
        ncurses-dev \
        postgresql \
        postgresql-dev && \
    # Remove files that we don't' need.
    rm -rf /usr/lib/libLLVM* \
           /usr/lib/libclang* \
           /usr/lib/llvm10 \
           /usr/lib/clang \
           /usr/include

COPY --from=dashboard-builder /usr/src/app/dist /app/bin/dashboard
COPY --from=server-builder    /app/bin/hakatime /app/bin/hakatime
COPY docker/init.sql          /app/init.sql
COPY docker/start.sh          /app/start.sh

ENV HAKA_PORT           8080
ENV HAKA_DASHBOARD_PATH /app/bin/dashboard

CMD ["/app/start.sh"]
