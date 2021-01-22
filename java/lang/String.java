package java.lang;

public class String {

	private byte[] bytes;

	public String(byte[] bytes) {
		this.bytes = new byte[bytes.length];
		System.arraycopy(bytes, 0, this.bytes, 0, bytes.length);
	}

	public byte[] getBytes() {
		byte[] b = new byte[bytes.length];
		System.arraycopy(bytes, 0, b, 0, bytes.length);
		return b;
	}

	public String concat(String str) {
		byte[] bstr = str.getBytes();
		byte[] bconcat = new byte[bytes.length + bstr.length];
		System.arraycopy(bytes, 0, bconcat, 0, bytes.length);
		System.arraycopy(bstr, 0, bconcat, bytes.length, bstr.length);
		return new String(bconcat);
	}

	public static native String valueOf(int i);

	public static String valueOf(boolean b) {
		return b ? "true" : "false";
	}

	public static String valueOf(Object obj) {
		if (obj == null) {
			return "null";
		} else {
			return obj.toString();
		}
	}

	public boolean equals(Object obj) {
		if (obj instanceof String) {
			return Arrays.equals(bytes, ((String) obj).bytes);
		} else {
			return false;
		}
	}
}
