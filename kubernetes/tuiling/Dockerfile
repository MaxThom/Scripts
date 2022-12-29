FROM ubuntu:jammy

RUN apt-get update -y \
    && apt-get upgrade -y \
    && apt install curl -y \
    && apt install git -y

WORKDIR /app

COPY tuiling.sh ./

CMD [ "./tuiling.sh" ]