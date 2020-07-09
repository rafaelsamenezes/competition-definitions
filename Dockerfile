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
    && apt-get install -y libc-dev python3-pip unzip python3-lxml python wget sudo git build-essential gcc-multilib \
    && pip3 install git+https://github.com/sosy-lab/benchexec.git coloredlogs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd benchexec \
    && adduser jenkins benchexec

RUN cp /etc/sudoers /etc/sudoers.bak && \
    echo 'jenkins  ALL=(root) NOPASSWD: ALL' >> /etc/sudoers && \
    mkdir /data && cd /data && pwd && \
    wget  https://github.com/sosy-lab/sv-benchmarks/archive/svcomp20.zip && \
    unzip svcomp20.zip && \
    rm -rf sv-benchmarks-svcomp20/clauses/ && \
    rm -rf sv-benchmarks-svcomp20/java && mv sv-benchmarks-svcomp20 sv-benchmarks

###################################
# jenkins user
###################################
USER jenkins
ENTRYPOINT ["/usr/local/bin/jenkins-slave"]
