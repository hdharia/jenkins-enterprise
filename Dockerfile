# Docker image for CloudBees Jenkins Enterprise

FROM java:8-jdk
MAINTAINER Harshal Dharia <Hdharia@cloudbees.com>
RUN apt-get update && apt-get install -y wget git curl zip && rm -rf /var/lib/apt/lists/*

ENV JENKINS_HOME /var/jenkins_home
ENV SSHD_HOST jenkins.beedemo.local
ENV JENKINS_PREFIX /cje
ENV JENKINS_SSH_PORT 2022
ENV JENKINS_HTTP_PORT 8080
ENV JENKINS_URL http://jenkins.beedemo.local:8080/cje
#when setting up in HA, set to flase to skip copying ref files and plugins as that only needs to be done once per HA cluster
ENV COPY_REF_FILES true

# Jenkins is ran with user `jenkins`, uid = 1000
# If you bind mount a volume from host/volume from a data container,
# ensure you use same uid
RUN useradd -d "$JENKINS_HOME" -u 1000 -m -s /bin/bash jenkins

# Jenkins home directoy is a volume, so configuration and build history
# can be persisted and survive image upgrades
VOLUME $JENKINS_HOME

# `/usr/share/jenkins/ref/` contains all reference configuration we want
# to set on a fresh new installation. Use it to bundle additional plugins
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

ENV TINI_SHA 066ad710107dc7ee05d3aa6e4974f01dc98f3888

# Use tini as subreaper in Docker container to adopt zombie processes
RUN curl -fL https://github.com/krallin/tini/releases/download/v0.5.0/tini-static -o /bin/tini && chmod +x /bin/tini \
  && echo "$TINI_SHA /bin/tini" | sha1sum -c -

COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/init_00_fixed-ports_url.groovy
COPY init-disable.groovy /usr/share/jenkins/ref/init.groovy.d/init_99_disable.groovy

ENV JENKINS_VERSION 1.642.18.1
ENV JENKINS_SHA 2203f94a9b8fbd8d767ba244726f63ef01175b95

# could use ADD but this one does not check Last-Modified header
# see https://github.com/docker/docker/issues/8331
RUN curl -fL http://jenkins-updates.cloudbees.com/download/je/$JENKINS_VERSION/jenkins.war -o /usr/share/jenkins/jenkins.war \
  && echo "$JENKINS_SHA /usr/share/jenkins/jenkins.war" | sha1sum -c -

RUN chown -R jenkins "$JENKINS_HOME" /usr/share/jenkins/ref

# for main web interface:
EXPOSE 8080

# will be used for ssh:
EXPOSE 2022

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

USER jenkins

COPY jenkins.sh /usr/local/bin/jenkins.sh
ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/jenkins.sh"]
#CMD /bin/bash /usr/local/bin/jenkins.sh $JENKINS_HOME/copy_reference_file.log

#CMD java -jar -Dorg.jenkinsci.main.modules.sshd.SSHD.hostName=${SSHD_HOST} jenkins.war --prefix=${JENKINS_PREFIX} --httpPort=${JENKINS_HTTP_PORT}
