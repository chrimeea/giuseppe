package java.lang;

public class StackTraceElement {
	
	private String className;
	private String methodName;
	private String fileName;
	private int lineNumber;

	public StackTraceElement(String declaringClass,
		String methodName,
		String fileName,
		int lineNumber) {
			this.className = declaringClass;
			this.methodName = methodName;
			this.fileName = fileName;
			this.lineNumber = lineNumber;
	}

	public String getClassName() {
		return className;
	}

	public String getMethodName() {
		return methodName;
	}

	public String getFileName() {
		return fileName;
	}

	public int getLineNumber() {
		return lineNumber;
	}
}