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

	public String toString() {
		return str;
	}
}