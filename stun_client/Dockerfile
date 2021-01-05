FROM elixir:1.11.2-alpine
ENV LANG=en_US.UTF-8

WORKDIR /app
COPY ./ .

RUN mix local.hex --force && \
    mix local.rebar --force && \
    MIX_ENV=prod mix release --overwrite

CMD _build/prod/rel/stun_client/bin/stun_client start
