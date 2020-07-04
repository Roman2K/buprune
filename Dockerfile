# --- Build image
FROM ruby:2.7.1-alpine3.11
WORKDIR /app

# bundle install deps
RUN apk add --update ca-certificates git build-base openssl-dev
RUN gem install bundler -v '>= 2'

# rclone
RUN cd /tmp \
  && wget https://github.com/rclone/rclone/releases/download/v1.52.2/rclone-v1.52.2-linux-amd64.zip \
  && unzip rclone-*.zip \
  && mv rclone-*/rclone .

# bundle install
COPY Gemfile* ./
RUN bundle

# --- Runtime image
FROM ruby:2.7.1-alpine3.11
WORKDIR /app

COPY --from=0 /usr/local/bundle /usr/local/bundle
COPY --from=0 /tmp/rclone /opt/rclone
RUN apk --update upgrade && apk add --no-cache ca-certificates

COPY . .
COPY ./docker/rclone /usr/bin/rclone
RUN addgroup -g 1000 -S app \
  && adduser -u 1000 -S app -G app \
  && chown -R app: .

USER app
RUN (cd \
  && mkdir -p .config/rclone \
  && chmod 700 .config)

ENTRYPOINT ["bundle", "exec", "ruby", "main.rb"]
CMD []
