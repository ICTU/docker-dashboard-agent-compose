FROM docker:1.10.3

RUN apk --update --no-cache add nodejs
RUN curl -L https://github.com/docker/compose/releases/download/1.9.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose \
  && chmod +x /usr/local/bin/docker-compose

ADD . /app

WORKDIR /app

RUN npm install

EXPOSE 80

CMD ["npm", "start"]
