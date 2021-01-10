package java.io;

public class FilterOutputStream extends OutputStream {

	protected OutputStream out;

	public FilterOutputStream(OutputStream out) {
		this.out = out;
	}
}