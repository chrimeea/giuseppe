public class Test {

	int prop1;
	long prop2;
	float prop3 = 1.5f;
	static boolean prop4;
	String prop5 = "abc.def";

	static {
		System.out.println("Init static");
	}

	{
		System.out.println("Init instance");
	}

	Test() {
		System.out.println("Init constructor");
		prop1 = 10;
	}

	private void boxing(Integer i) {
		System.out.println("Boxing " + i);
	}

	public int[] sort(String... args) {
		int i;
		int[] n = new int[args.length];
		for (i = 0; i < args.length; i++) {
			n[i] = Integer.parseInt(args[i]);
		}
		boolean sorted;
		do {
			sorted = true;
			for (i = 0; i < args.length - 1; i++) {
				if (n[i] > n[i + 1]) {
					int aux = n[i];
					n[i] = n[i + 1];
					n[i + 1] = aux;
					sorted = false;
				}
			}
		} while (!sorted);
		return n;
	}

	public void print(int[] n) {
		int i;
		for (i = 0; i < n.length - 1; i++) {
			System.out.print(n[i]);
			System.out.print(", ");
		}
		System.out.println(n[i]);
	}

	void wrong(int[] n) {
		int i = n[-1];
	}

	boolean complex(Test t, double f, long[][] y, double[][][] z, Object o) {
		return true;
	}

	public static void main(String... args) {
		Test t2 = new Test();
		int j = 12;
		t2.boxing(j);
		System.out.println(t2.complex(null, 0, null, null, null));
		Test t = new Test();
		int[] n = t.sort(args);
		t.print(n);
		System.out.println("Prop1 = " + t.prop1);
		System.out.println("Prop2 = " + t.prop2);
		System.out.println("Prop3 = " + t.prop3);
		System.out.println("Prop4 = " + t.prop4);
		System.out.println("Prop4 = " + Test.prop4);
		System.out.println("Prop5 = " + t.prop5.replace('.', '/'));
		try {
			throw new RuntimeException();
		} catch (RuntimeException e) {
			e.printStackTrace();
		} finally {
			System.out.println("continuare...");
		}
		System.out.println(int[].class);
		System.out.println(n.getClass());
		System.out.println(t.getClass());
		Test2 c2 = new Test3();
		c2.n();
		Test1 c1 = new Test3();
		c1.m();
		((Test3) c2).m();
		System.out.println(c1.getClass());
		System.out.println(c1 instanceof Test3);
		System.out.println(c1 instanceof Test2);
		System.out.println(c1 instanceof Test1);
		System.out.println(c1 instanceof Object);
		System.out.println(n instanceof Object);
		System.out.println(new Object() instanceof Test3);
		t2.wrong(n);
		System.out.println("done.");
	}
}

interface Test1 {
	void m();
}

abstract class Test2 {
	abstract void n();
}

class Test3 extends Test2 implements Test1 {
	public void m() {
		System.out.println("interface call");
	}

	void n() {
		System.out.println("abstract call");
	}
}
