FROM docker:1.12.6

RUN apk --update --no-cache add nmap nodejs coreutils 'py-pip==8.1.2-r0' && pip install 'docker-compose==1.14.0'

ADD . /app

WORKDIR /app

RUN npm install --production

EXPOSE 80

CMD ["npm", "start"]
