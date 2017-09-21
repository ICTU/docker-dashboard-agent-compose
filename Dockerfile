FROM docker:17.07

RUN apk --update --no-cache add nmap nodejs-npm coreutils 'py-pip==9.0.1-r1' && pip install 'docker-compose==1.16.1'

ADD . /app

WORKDIR /app

RUN npm install --production

EXPOSE 80

CMD ["npm", "start"]
