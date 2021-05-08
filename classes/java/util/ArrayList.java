package java.util;

public class ArrayList<E> {
	
	private int size = 0;
	private Object[] elements = new Object[10];

	public int size() {
		return size;
	}

	public boolean add(E e) {
		if (size == elements.length) {
			Object[] other = new Object[size * 2];
			System.arraycopy(elements, 0, other, 0, size);
			elements = other;
		}
		elements[size] = e;
		size++;
		return true;
	}

	public E get(int index) {
		return (E) elements[index];
	}

	public int indexOf(Object o) {
		for (int i = 0; i < size; i++) {
			if ((elements[i] == null && o == null) || elements[i].equals(o)) {
				return i;
			}
		}
		return -1;
	}
}