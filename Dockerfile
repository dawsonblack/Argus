#Elixir base image
FROM hexpm/elixir:1.18.4-erlang-28.0.2-debian-bullseye-20250630-slim AS build

RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    nodejs \
    npm \
    inotify-tools \
    postgresql-client \
    python3 \
    python3-pip \
    bluez \
    libglib2.0-dev \
    dbus

#set work directory, adds essentials for project setup
WORKDIR /app

COPY mix.exs mix.lock ./
COPY config config
RUN mix local.hex --force && mix local.rebar --force && mix deps.get

#add the rest of the project
COPY . .
RUN pip3 install --no-cache-dir bleak
RUN MIX_ENV=dev mix compile

#initialize the project and start it
#RUN chmod +x /app/docker-entrypoint.sh
#ENTRYPOINT ["/app/docker-entrypoint.sh"]