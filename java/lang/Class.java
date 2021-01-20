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
		} else {
			return "class " + name;
		}
	}
}