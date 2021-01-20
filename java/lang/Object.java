package java.lang;

public class Object {

	public final native Class<?> getClass();

	public native int hashCode();

	public boolean equals(Object obj) {
		return this == obj;
	}

	public String toString() {
		return getClass().getName() + "@" + hashCode();
	}
}
