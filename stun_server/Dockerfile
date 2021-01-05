FROM elixir:1.11.2-alpine
ENV LANG=en_US.UTF-8

WORKDIR /app
COPY ./ .

RUN mix local.hex --force && \
    mix local.rebar --force && \
    MIX_ENV=prod mix compile

CMD mix run --no-halt
