FROM perl:5.22
MAINTAINER Mesosphere <support@mesosphere.com>
RUN git clone https://github.com/dmgerman/ninka && \
    cd ninka && \
    perl Makefile.PL && \
    make && \
    make install && \
    cd .. && \
    rm -rf ninka
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -qqy \
        jq && \
    apt-get clean
COPY ./godep-licenses.sh /usr/local/bin/
ENTRYPOINT [ "/usr/local/bin/godep-licenses.sh" ]
