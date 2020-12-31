Implementation of the java virtual machine 1.6 for educational purposes written in Ruby.
Supports ints, arrays, strings and objects.
Supports instance and static method invocations (no interfaces yet).
Supports exceptions (no stack trace yet).
Incomplete virtual machine instruction set, no native support, no thread support.
Incomplete java lang classes.
Classpath is only the current folder.

javac -source 1.6 -target 1.6 java/lang/*.java

Usage example:
javac -source 1.6 -target 1.6 Test.java
./java.rb Test
