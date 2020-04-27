ARG BASE_IMAGE_PREFIX
FROM ${BASE_IMAGE_PREFIX}debian:buster-slim

# mimic_pkg defaults to installing from the remote repo. To make sure you
# install the version that accompanied this Mycroft AI release, uncomment the
# right package for your architecture.
ARG mimic_pkg=mimic
# ARG mimic_pkg=./mimic_1.3.0.0_amd64.deb
# ARG mimic_pkg=./mimic_1.3.0.1_armhf.deb
# ARG mimic_pkg=./mimic_1.2.0.2+1559651054_arm64.deb

ARG host_locale=en_US.UTF-8

ENV TERM linux
ENV DEBIAN_FRONTEND noninteractive

# Install Server Dependencies for Mycroft
RUN set -x \
    	&& apt-get update \
	&& apt-get -y install git python3 python3-pip locales sudo \
	&& pip3 install future msm \
	# Checkout Mycroft
	&& git clone --branch=release/v20.2.2 \
	https://github.com/MycroftAI/mycroft-core.git /opt/mycroft \
	&& cd /opt/mycroft \
	&& mkdir /opt/mycroft/skills \
	&& CI=true /opt/mycroft/./dev_setup.sh --allow-root -sm \
	&& mkdir /opt/mycroft/scripts/logs \
	&& touch /opt/mycroft/scripts/logs/mycroft-bus.log \
	&& touch /opt/mycroft/scripts/logs/mycroft-voice.log \
	&& touch /opt/mycroft/scripts/logs/mycroft-skills.log \
	&& touch /opt/mycroft/scripts/logs/mycroft-audio.log

COPY packages/ /opt/mycroft
RUN curl https://forslund.github.io/mycroft-desktop-repo/mycroft-desktop.gpg.key \
	| apt-key add - 2> /dev/null \
	&& echo "deb http://forslund.github.io/mycroft-desktop-repo bionic main" \
	> /etc/apt/sources.list.d/mycroft-desktop.list \
	&& cd /opt/mycroft \
	&& apt-get update \
	&& apt install -y $mimic_pkg \
	&& apt-get -y autoremove \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
	&& rm -f ./mimic_*.deb

# Set the locale
RUN sed -i -e 's/# \('"$host_locale"' .*\)/\1/' /etc/locale.gen \
    	&& dpkg-reconfigure --frontend=noninteractive locales \
	&& update-locale LANG=$host_locale

WORKDIR /opt/mycroft
COPY startup.sh /opt/mycroft
ENV PYTHONPATH $PYTHONPATH:/mycroft/ai

RUN echo "PATH=$PATH:/opt/mycroft/bin" >> $HOME/.bashrc \
        && echo "source /opt/mycroft/.venv/bin/activate" >> $HOME/.bashrc

RUN chmod +x /opt/mycroft/start-mycroft.sh \
	&& chmod +x /opt/mycroft/startup.sh

EXPOSE 8181

ENTRYPOINT "/opt/mycroft/startup.sh"
