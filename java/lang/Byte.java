package java.lang;

public class Byte {

	public static Class TYPE = Class.forName("B");

	public Byte(byte b) {}

	public Byte valueOf(byte b) {
		return new Byte(b);
	}
}