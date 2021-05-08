package java.lang;

public class Character {

	public static Class TYPE = Class.forName("C");

	public Character(char c) {}

	public Character valueOf(char c) {
		return new Character(c);
	}
}