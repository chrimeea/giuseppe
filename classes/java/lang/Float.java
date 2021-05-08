package java.lang;

public class Float {

	public static Class TYPE = Class.forName("F");

	public Float(float f) {}

	public static Float valueOf(float f) {
		return new Float(f);
	}
}