package java.lang;

import java.io.*;

public class System {

	public static PrintStream out = new PrintStream(new OutputStream() {
		public native void write(byte[] b);
	});
}