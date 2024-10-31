FROM maven:3.8-openjdk-18

WORKDIR /app

COPY . /app

RUN mvn clean install

EXPOSE 8080

CMD ["java", "-jar", "target/mavenproject1-1.0-SNAPSHOT.jar"]
