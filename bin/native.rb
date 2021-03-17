# frozen_string_literal: true

def Java_lang_jni_System_1_write _, params
	print params[1].values.pack('c*')
end

def Java_lang_jni_System_2_write _, params
	$stderr.print params[1].values.pack('c*')
end

def Java_lang_jni_System_arraycopy _, params
	src, srcpos, dst, dstpos, length = params
	dst.values[dstpos...(dstpos + length)] = src.values[srcpos...(srcpos + length)]
end

def Java_lang_jni_Object_hashCode _, params
	params.first.hash
end

def Java_lang_jni_Object_getClass jvm, params
	jvm.new_java_class params.first.jvmclass.class_type
end

def Java_lang_jni_String_valueOf jvm, params
	jvm.new_java_string params.first.to_s
end

def Java_lang_jni_Integer_parseInt jvm, params
	jvm.java_to_native_string(params.first).to_i
end

def Java_lang_jni_Class_isInterface jvm, params
	reference = params.first
	field = JavaField.new('name', 'Ljava/lang/String;')
	nameref = jvm.get_field(reference, reference.jvmclass, field)
	jvmclass = jvm.load_class(jvm.java_to_native_string(nameref))
	!jvmclass.array? && jvmclass.access_flags.interface? ? 1 : 0
end

def Java_lang_jni_Throwable_fillInStackTrace jvm, params
	reference = params.first
	elem_class_type = 'java/lang/StackTraceElement'
	array_class_type = "[L#{elem_class_type};"
	stacktrace = []
	jvmclass = jvm.load_class elem_class_type
	jvm.frames.each do |f|
		break if f.jvmclass.class_type == reference.jvmclass.class_type
		stacktrace << jvm.new_java_object_with_constructor(
				jvmclass,
				JavaMethod.new(
						'<init>',
						'(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;I)V'
				),
				[jvm.new_java_string(f.jvmclass.class_type),
					jvm.new_java_string(f.method.method_name),
					jvm.new_java_string(f.jvmclass.source_file),
					f.line_number]
		)
	end
	arrayref = jvm.new_java_array(jvm.load_class(array_class_type), [stacktrace.size])
	stacktrace.reverse.each_with_index { |s, i| arrayref.values[i] = s }
	method = JavaMethod.new('setStackTrace', "(#{array_class_type})V")
	jvm.run reference.jvmclass, method, [reference, arrayref]
	reference
end
