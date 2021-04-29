Implementation of the java virtual machine 1.6 for educational purposes written in Ruby.
Supports primitive types, arrays, objects and strings (not unicode).
Supports instance and static method invocations.
Supports inheritance, abstract classes and interfaces.
Supports exceptions.
Supports native code (no jni support).
Incomplete virtual machine instruction set, no thread support.
Incomplete java lang classes.
Classpath is only the current folder.

javac -Xlint:-options -source 1.6 -target 1.6 -bootclasspath . java/lang/*.java

Usage example to compile and run a Test.java file:
javac -Xlint:-options -source 1.6 -target 1.6 Test.java
./bin/java.rb Test

JVM 6 specs:
https://docs.oracle.com/javase/specs/jvms/se6/html/VMSpecTOC.doc.html

Listing of Giuseppe JVM implementation classes:

┌------------------------------------┐
|program                             |
├------------------------------------┤
|jvm                                 |
├------------------------------------┤
|scheduler                           |
|resolver                            |
|allocator                           |
|operationdispatcher                 |
|operations                          |
├------------------------------------┤
|frame                               |
|javainstance                        |
|javaarrayinstance                   |
|javaclass                           |
|javafieldhandle                     |
|javamethodhandle                    |
|typedescriptor                      |
|methoddescriptor                    |
├------------------------------------┤
|classfile                           |
|classfileloader                     |
|classfield                          |
|classfieldlist                      |
|classattribute + ...                |
|classattributelist                  |
|interfacelist                       |
|constantpool                        |
|constantpoolconstant + ...          |
├------------------------------------┤
|binaryparser                        |
└------------------------------------┘