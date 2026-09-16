package java.io;

public abstract class InputStream implements Closeable {

  public int available() {
    return 0;
  }

  public void close() {
  }

  public boolean markSupported() {
    return false;
  }

  public abstract int read();

  public int read(byte[] b) {
    return 0;
  }

  public int read(byte[] b, int off, int len) {
    return 0;
  }

  public void reset() {
  }

  public long skip(long n) {
    return 0;
  }
}
