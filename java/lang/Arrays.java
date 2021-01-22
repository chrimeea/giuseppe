package java.lang;

public class Arrays {

	public static boolean equals(byte[] a1, byte[] a2) {
		if (a1 == null && a2 == null) {
			return true;
		} else if (a1 != null || a2 != null) {
			return false;
		} else if (a1.length == a2.length) {
			for (int i = 0; i < a1.length; i++) {
				if (a1[i] != a2[i]) {
					return false;
				}
			}
			return true;
		} else {
			return false;
		}
		
	}
}