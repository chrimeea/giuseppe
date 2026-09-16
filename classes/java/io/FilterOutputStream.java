package java.io;

public class FilterOutputStream extends OutputStream {

	protected OutputStream out;

	public FilterOutputStream(OutputStream out) {
		this.out = out;
	}

	public void close() {}
	public void flush() {}
	public void write(byte[] b) {}
	public void write(byte[] b, int off, int len) {}
	public void write(int b) {}
}
