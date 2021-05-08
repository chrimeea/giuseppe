package java.lang;

public class Double {

	public static Class TYPE = Class.forName("D");

	public Double(double d) {}

	public Double valueOf(double d) {
		return new Double(d);
	}
}