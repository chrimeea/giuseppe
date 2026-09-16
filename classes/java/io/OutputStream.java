package java.io;

public abstract class OutputStream implements Closeable, Flushable {

	public void close() {}
	public void flush() {}
	public void write(byte[] b) {}
	public void write(byte[] b, int off, int len) {}
	public abstract void write(int b);
}
