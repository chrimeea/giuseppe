package java.io;

public class PrintStream extends FilterOutputStream {

	private byte[] nl = new byte[] {10};

	public PrintStream(OutputStream out) {
		super(out);
	}

	public void println() {
		out.write(nl);
	}

	public void print(String s) {
		out.write(s.getBytes());
	}

	public void println(String s) {
		print(s);
		println();
	}

}