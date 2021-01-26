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

	public void print(int i) {
		print(String.valueOf(i));
	}

	public void print(double d) {
		print(String.valueOf(d));
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

	public void println(double d) {
		print(d);
		println();
	}

	public void println(int i) {
		print(i);
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