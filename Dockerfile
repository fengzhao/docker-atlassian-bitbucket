FROM ghcr.io/fengzhao/openjdk:8-jdk-alpine-chinese-timezone

ARG RELEASE_VERSION=7.6.5 
# permissions
ARG CONTAINER_UID=1000
ARG CONTAINER_GID=1000

ENV BITBUCKET_HOME=/var/atlassian/bitbucket \
    BITBUCKET_INSTALL=/opt/bitbucket \
    BITBUCKET_PROXY_NAME= \
    BITBUCKET_PROXY_PORT= \
    BITBUCKET_PROXY_SCHEME= \
    BITBUCKET_BACKUP_CLIENT=/opt/backupclient/bitbucket-backup-client \
    BITBUCKET_BACKUP_CLIENT_HOME=/opt/backupclient \
    BITBUCKET_BACKUP_CLIENT_VERSION=300300300

RUN export MYSQL_DRIVER_VERSION=5.1.48 && \
    export CONTAINER_USER=bitbucket &&  \
    export CONTAINER_GROUP=bitbucket &&  \
    addgroup -g $CONTAINER_GID $CONTAINER_GROUP &&  \
    adduser -u $CONTAINER_UID \
            -G $CONTAINER_GROUP \
            -h /home/$CONTAINER_USER \
            -s /bin/bash \
            -S $CONTAINER_USER &&  \
    apk add --update \
      tini \
      bash \
      su-exec \
      ca-certificates \
      gzip \
      curl \
      openssh \
      util-linux \
      git \
      perl \
      wget  \
      ttf-dejavu \
      git-daemon && \
    echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf && \
    curl https://raw.githubusercontent.com/vishnubob/wait-for-it/55c54a5abdfb32637b563b28cc088314b162195e/wait-for-it.sh -o /usr/bin/wait-for-it && \
    # Install xmlstarlet
    export XMLSTARLET_VERSION=1.6.1-r1              &&  \
    wget --directory-prefix=/tmp https://github.com/menski/alpine-pkg-xmlstarlet/releases/download/${XMLSTARLET_VERSION}/xmlstarlet-${XMLSTARLET_VERSION}.apk && \
    apk add --allow-untrusted /tmp/xmlstarlet-${XMLSTARLET_VERSION}.apk && \
    wget -O /tmp/bitbucket.tar.gz  https://product-downloads.atlassian.com/software/stash/downloads/atlassian-bitbucket-${RELEASE_VERSION}.tar.gz && \
    tar zxf /tmp/bitbucket.tar.gz -C /tmp && \
    mv /tmp/atlassian-bitbucket-${RELEASE_VERSION} /tmp/bitbucket && \
    mkdir -p ${BITBUCKET_HOME} && \
    mkdir -p /opt && \
    mv /tmp/bitbucket /opt/bitbucket && \
    # Install database drivers
    rm -f                                               \
      ${BITBUCKET_INSTALL}/lib/mysql-connector-java*.jar &&  \
    wget -O /tmp/mysql-connector-java-${MYSQL_DRIVER_VERSION}.tar.gz                                              \
      http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MYSQL_DRIVER_VERSION}.tar.gz && \
    tar xzf /tmp/mysql-connector-java-${MYSQL_DRIVER_VERSION}.tar.gz                                              \
      -C /tmp && \
    cp /tmp/mysql-connector-java-${MYSQL_DRIVER_VERSION}/mysql-connector-java-${MYSQL_DRIVER_VERSION}-bin.jar     \
      ${BITBUCKET_INSTALL}/lib/mysql-connector-java-${MYSQL_DRIVER_VERSION}-bin.jar                                &&  \
    # Adding letsencrypt-ca to truststore
    export KEYSTORE=$JAVA_HOME/jre/lib/security/cacerts && \
    wget -P /tmp/ https://letsencrypt.org/certs/lets-encrypt-x1-cross-signed.der && \
    wget -P /tmp/ https://letsencrypt.org/certs/lets-encrypt-x2-cross-signed.der && \
    wget -P /tmp/ https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.der && \
    wget -P /tmp/ https://letsencrypt.org/certs/lets-encrypt-x4-cross-signed.der && \
    keytool -trustcacerts -keystore $KEYSTORE -storepass changeit -noprompt -importcert -alias letsencryptauthorityx1 -file /tmp/lets-encrypt-x1-cross-signed.der && \
    keytool -trustcacerts -keystore $KEYSTORE -storepass changeit -noprompt -importcert -alias letsencryptauthorityx2 -file /tmp/lets-encrypt-x2-cross-signed.der && \
    keytool -trustcacerts -keystore $KEYSTORE -storepass changeit -noprompt -importcert -alias letsencryptauthorityx3 -file /tmp/lets-encrypt-x3-cross-signed.der && \
    keytool -trustcacerts -keystore $KEYSTORE -storepass changeit -noprompt -importcert -alias letsencryptauthorityx4 -file /tmp/lets-encrypt-x4-cross-signed.der && \
    # Install atlassian ssl tool
    wget -O /home/${CONTAINER_USER}/SSLPoke.class https://confluence.atlassian.com/kb/files/779355358/779355357/1/1441897666313/SSLPoke.class && \
    # Container user permissions
    chown -R bitbucket:bitbucket /home/${CONTAINER_USER} && \
    chown -R bitbucket:bitbucket ${BITBUCKET_HOME} && \
    chown -R bitbucket:bitbucket ${BITBUCKET_INSTALL}

# Remove obsolete packages
RUN apk del \
      ca-certificates \
      gzip \
      util-linux \
      wget &&  \
    # Clean caches and tmps
    rm -rf /var/cache/apk/* && \
    rm -rf /tmp/* && \
    rm -rf /var/log/*


USER root

# 将代理破解包加入容器
COPY "atlassian-agent.jar" /opt/atlassian/bitbucket/

# 设置启动加载代理包
#RUN echo 'export JMX_OPTS="-javaagent:/opt/atlassian/bitbucket/atlassian-agent.jar ${JMX_OPTS}"' >> /opt/bitbucket/bin/set-jmx-opts.sh
# 找到 /opt/bitbucket/bin/_start-webapp.sh 文件中以"JAVA_OPTS="开头的行，并在其后添加一句export JAVA_OPTS="-javaagent:/opt/atlassian/bitbucket/atlassian-agent.jar ${JAVA_OPTS}"
RUN sed -i '/^JAVA_OPTS=/a     export JAVA_OPTS="-javaagent:/opt/atlassian/bitbucket/atlassian-agent.jar ${JAVA_OPTS}"'   /opt/bitbucket/bin/_start-webapp.sh


USER bitbucket
WORKDIR /var/atlassian/bitbucket
VOLUME ["/var/atlassian/bitbucket"]
EXPOSE 7990 7990
EXPOSE 7999 7999
EXPOSE 7992 7992
COPY docker-entrypoint.sh /
COPY ps_opt_p_enabled_for_alpine.sh /usr/bin/ps
ENTRYPOINT ["/sbin/tini","--","/docker-entrypoint.sh"]
CMD ["bitbucket"]
