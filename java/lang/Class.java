package java.lang;

public class Class<T> {

	private String name;

	private Class(String name) {
		this.name = name;
	}

	public String getName() {
		if (name.charAt(0) == 'L') {
			return name.substring(1, name.length() - 1);
		} else {
			return name;
		}
	}

	public static Class<?> forName(String className) {
		return new Class("L" + className.replace('.', '/') + ";");
	}

	public boolean desiredAssertionStatus() {
		return true;
	}

	public boolean isArray() {
		return name.length() > 1 && name.charAt(0) == '[';
	}

	public native boolean isInterface();

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
		} else if (isInterface()) {
			return "interface " + getName();
		} else {
			return "class " + getName();
		}
	}
}