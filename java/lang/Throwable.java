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
		System.err.println(toString());
	}

	public String toString() {
		StringBuilder s = new StringBuilder();
		s.append(getClass().getName()).append("\n");
		if (stackTrace != null) {
			for (int i = 0; i < stackTrace.length; i++) {
				s.append("\tat ")
					.append(stackTrace[i].getClassName())
					.append(".")
					.append(stackTrace[i].getMethodName())
					.append("(")
					.append(stackTrace[i].getFileName())
					.append(":")
					.append(stackTrace[i].getLineNumber())
					.append(")\n");
			}
		}
		return s.toString();
	}

	public native Throwable fillInStackTrace();
}