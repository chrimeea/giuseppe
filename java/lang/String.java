package java.lang;

public class String {

	private byte[] bytes;

	public String(byte[] bytes) {
		this.bytes = bytes;
	}

	public byte[] getBytes() {
		return bytes;
	}
}
