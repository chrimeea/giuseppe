package java.lang;

public class Class<T> {

	private String name;

	private Class(String name) {
		this.name = name;
	}

	public String getName() {
		return name;
	}

	public static Class<?> forName(String className) {
		return new Class(className);
	}

	public String toString() {
		if (this == Void.TYPE) {
			return "void";
		} else if (this == Byte.TYPE) {
			return "byte";
		} else if (this == Short.TYPE) {
			return "short";
		} else if (this == Character.TYPE) {
			return "char";
		} else if (this == Boolean.TYPE) {
			return "boolean";
		} else if (this == Float.TYPE) {
			return "float";
		} else if (this == Long.TYPE) {
			return "long";
		} else if (this == Double.TYPE) {
			return "double";
		} else if (this == Integer.TYPE) {
			return "int";
		} else {
			return "class " + name;
		}
	}
}