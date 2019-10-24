FROM centos:latest
WORKDIR /config
ENV LC_ALL=en_US.UTF-8 \
    GUAC_VER=1.0.0 \
    TOMCAT_VER=9.0.27

ARG Required_dependencies="\
            cairo-devel \
            libjpeg-turbo-devel \
            libpng-devel \
            uuid-devel \
            "
ARG Optional_dependencies="\
            ffmpeg-devel \
            freerdp1.2-devel \
            pango-devel \
            libssh2-devel \
            libtelnet-devel \
            libvncserver-devel \
            pulseaudio-libs-devel \
            openssl-devel \
            libvorbis-devel \
            libwebp-devel \
            ghostscript \
            "

RUN set -ex \
    && yum -y install epel-release \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && mkdir /usr/local/lib/freerdp/ \
    && ln -s /usr/local/lib/freerdp /usr/lib64/freerdp \
    && rpm --import http://li.nux.ro/download/nux/RPM-GPG-KEY-nux.ro \
    && rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm \
    && yum -y localinstall --nogpgcheck https://mirrors.aliyun.com/rpmfusion/free/el/rpmfusion-free-release-7.noarch.rpm https://mirrors.aliyun.com/rpmfusion/nonfree/el/rpmfusion-nonfree-release-7.noarch.rpm \
    && yum install -y make \
            gcc \
            libtool \
            java-1.8.0-openjdk \
            wget \
    && yum install -y $Required_dependencies \
    && yum install -y $Optional_dependencies \
    && mkdir -p /config/guacamole /config/guacamole/lib /config/guacamole/extensions /config/guacamole/data/log/ \
    && wget http://mirrors.tuna.tsinghua.edu.cn/apache/tomcat/tomcat-9/v${TOMCAT_VER}/bin/apache-tomcat-${TOMCAT_VER}.tar.gz \
    && tar xf apache-tomcat-${TOMCAT_VER}.tar.gz \
    && mv apache-tomcat-${TOMCAT_VER} tomcat9 \
    && rm -rf apache-tomcat-${TOMCAT_VER}.tar.gz \
    && rm -rf tomcat9/webapps/* \
    && sed -i 's/Connector port="8080"/Connector port="8081"/g' /config/tomcat9/conf/server.xml \
    && sed -i 's/level = FINE/level = OFF/g' /config/tomcat9/conf/logging.properties \
    && sed -i 's/level = INFO/level = OFF/g' /config/tomcat9/conf/logging.properties \
    && sed -i 's@CATALINA_OUT="$CATALINA_BASE"/logs/catalina.out@CATALINA_OUT=/dev/null@g' /config/tomcat9/bin/catalina.sh \
    && sed -i 's/# export/export/g' /root/.bashrc \
    && sed -i 's/# alias l/alias l/g' /root/.bashrc \
    && echo "java.util.logging.ConsoleHandler.encoding = UTF-8" >> /config/tomcat9/conf/logging.properties \
    && yum clean all \
    && rm -rf /var/cache/yum/*

# Install guacamole-server
COPY guacamole-server-${GUAC_VER}.tar.gz .
# RUN curl -SLO "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VER}/source/guacamole-server-${GUAC_VER}.tar.gz" \
RUN tar -xzf guacamole-server-${GUAC_VER}.tar.gz \
    && cd guacamole-server-${GUAC_VER} \
    && ./configure \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make install \
    && cd .. \
    && rm -rf guacamole-server-${GUAC_VER}.tar.gz guacamole-server-${GUAC_VER} \
    && ldconfig

# Install guacamole-client
#  RUN curl -SLo /config/tomcat9//webapps/ROOT.war "https://sourceforge.net/projects/guacamole/files/current/binary/guacamole-${GUAC_VER}.war"
COPY guacamole-${GUAC_VER}.war /config/tomcat9/webapps/ROOT.war

# curl -SLo /config/guacamole/extensions/guacamole-auth-jumpserver-${GUAC_VER}.jar "https://s3.cn-north-1.amazonaws.com.cn/tempfiles/guacamole-jumpserver/guacamole-auth-jumpserver-${GUAC_VER}.jar"
COPY guacamole-auth-jumpserver-${GUAC_VER}.jar /config/guacamole/extensions/guacamole-auth-jumpserver-${GUAC_VER}.jar

# Install ssh-forward for support
RUN curl -SLo /tmp/linux-amd64.tar.gz "https://github.com/ibuler/ssh-forward/releases/download/v0.0.5/linux-amd64.tar.gz" \
  && tar xvf /tmp/linux-amd64.tar.gz -C /bin/ && chmod +x /bin/ssh-forward \
  && rm -rf /tmp/linux-amd64.tar.gz

COPY root/app/guacamole/guacamole.properties /config/guacamole/guacamole.properties

COPY entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh

ENV JUMPSERVER_KEY_DIR=/config/guacamole/keys \
    GUACAMOLE_HOME=/config/guacamole \
    JUMPSERVER_CLEAR_DRIVE_SESSION=true \
    JUMPSERVER_ENABLE_DRIVE=true

ENTRYPOINT [ "./entrypoint.sh" ]
