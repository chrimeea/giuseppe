package java.lang;

import java.io.*;

public class System {

	public static PrintStream out = new PrintStream(new OutputStream() {
		public native void write(byte[] b);
	});

	public static PrintStream err = new PrintStream(new OutputStream() {
		public native void write(byte[] b);
	});

	public static native void arraycopy(Object src,
             int srcPos,
             Object dest,
             int destPos,
             int length);
}