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

	public StringBuilder append(float i) {
		return append(String.valueOf(i));
	}

	public StringBuilder append(Object obj) {
		return append(String.valueOf(obj));
	}

	public String toString() {
		return str;
	}
}