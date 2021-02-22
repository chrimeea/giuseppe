package java.io;

public class PrintStream extends FilterOutputStream {

	private byte[] nl = new byte[] {10};

	public PrintStream(OutputStream out) {
		super(out);
	}

	public void println() {
		out.write(nl);
	}

	public void print(boolean b) {
		print(String.valueOf(b));
	}

	public void print(byte b) {
		print(String.valueOf(b));
	}

	public void print(short s) {
		print(String.valueOf(s));
	}

	public void print(int i) {
		print(String.valueOf(i));
	}

	public void print(long l) {
		print(String.valueOf(l));
	}

	public void print(float f) {
		print(String.valueOf(f));
	}

	public void print(double d) {
		print(String.valueOf(d));
	}

	public void print(char c) {
		print(String.valueOf(c));
	}

	public void print(String s) {
		out.write(s.getBytes());
	}

	public void print(Object obj) {
		print(String.valueOf(obj));
	}

	public void println(boolean b) {
		print(b);
		println();
	}

	public void println(char c) {
		print(c);
		println();
	}

	public void println(long l) {
		print(l);
		println();
	}

	public void println(float f) {
		print(f);
		println();
	}

	public void println(double d) {
		print(d);
		println();
	}

	public void println(int i) {
		print(i);
		println();
	}

	public void println(short s) {
		print(s);
		println();
	}

	public void println(byte b) {
		print(b);
		println();
	}

	public void println(String s) {
		print(s);
		println();
	}

	public void println(Object s) {
		print(s);
		println();
	}
}