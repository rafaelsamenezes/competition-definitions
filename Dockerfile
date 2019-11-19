###################################
# START
###################################
FROM jenkins/jnlp-slave

###################################
# ROOT
###################################
USER root
# Core Packages
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y python3-pip python wget sudo git \
    && pip3 install BenchExec \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd benchexec \
    && adduser jenkins benchexec

RUN cp /etc/sudoers /etc/sudoers.bak && \
    echo 'jenkins  ALL=(root) NOPASSWD: ALL' >> /etc/sudoers && \
    mkdir /data && cd /data && pwd && \
    git clone --depth 1 https://github.com/sosy-lab/sv-benchmarks.git


###################################
# jenkins user
###################################
USER jenkins
ENTRYPOINT ["/usr/local/bin/jenkins-slave"]
