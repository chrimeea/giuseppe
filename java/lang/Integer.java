package java.lang;

public class Integer {

	public static Class TYPE = Class.forName("I");

	public Integer(int i) {}

	public static native int parseInt(String s);
}