package java.lang;

public class Boolean {

	public static Class TYPE = Class.forName("Z");

	public Boolean(boolean b) {}

	public Boolean valueOf(boolean b) {
		return new Boolean(b);
	}
}