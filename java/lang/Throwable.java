package java.lang;

public class Throwable {

	private StackTraceElement[] stackTrace;

	public Throwable() {
		fillInStackTrace();
	}

	public void setStackTrace(StackTraceElement[] stackTrace) {
		this.stackTrace = stackTrace;
	}

	public void printStackTrace() {
		System.out.println(toString());
	}

	public native Throwable fillInStackTrace();
}