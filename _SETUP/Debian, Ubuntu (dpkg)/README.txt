The legacy Debian package was removed because it downloaded the obsolete Java 7 build over HTTP.

Build the current JAR from the repository root with Maven:

    mvn clean package

It can then be run on a desktop system with:

    java -jar target/NoteBot-1.7.3.jar
