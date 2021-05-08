package java.lang;

public class Long {

	public static Class TYPE = Class.forName("J");

	public Long(long l) {}

	public static Long valueOf(long l) {
		return new Long(l);
	}
}