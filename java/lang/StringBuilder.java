package java.lang;

public class StringBuilder {
	
	private String str = "";

	public StringBuilder append(String str) {
		if (str == null) {
			str = "null";
		}
		this.str = this.str.concat(str);
		return this;
	}

	public StringBuilder append(int i) {
		return append(String.valueOf(i));
	}

	public StringBuilder append(long l) {
		return append(String.valueOf(l));
	}

	public StringBuilder append(double d) {
		return append(String.valueOf(d));
	}

	public StringBuilder append(boolean b) {
		return append(String.valueOf(b));
	}

	public StringBuilder append(char c) {
		return append(String.valueOf(c));
	}

	public StringBuilder append(float f) {
		return append(String.valueOf(f));
	}

	public StringBuilder append(Object obj) {
		return append(String.valueOf(obj));
	}

	public String toString() {
		return str;
	}
}