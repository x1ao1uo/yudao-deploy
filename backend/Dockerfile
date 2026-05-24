FROM eclipse-temurin:latest

WORKDIR /yudao-server

ARG SERVER_JAR=ruoyi-vue-pro/yudao-server/target/yudao-server.jar
COPY ${SERVER_JAR} app.jar

ENV TZ=Asia/Shanghai
ENV JAVA_OPTS="-Xms512m -Xmx512m -Djava.security.egd=file:/dev/./urandom"
ENV ARGS=""

EXPOSE 48080

CMD java ${JAVA_OPTS} -jar app.jar ${ARGS}
