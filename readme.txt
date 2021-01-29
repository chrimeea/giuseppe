Implementation of the java virtual machine 1.6 for educational purposes written in Ruby.
Supports primitive types, arrays, objects and strings (not unicode).
Supports instance and static method invocations.
Supports inheritance, abstract classes and interfaces.
Supports exceptions.
Supports native code (no jni support).
Incomplete virtual machine instruction set, no thread support.
Incomplete java lang classes.
Classpath is only the current folder.

javac -source 1.6 -target 1.6 java/lang/*.java
javac -source 1.6 -target 1.6 java/io/*.java

Usage example:
javac -source 1.6 -target 1.6 Test.java
./java.rb Test
