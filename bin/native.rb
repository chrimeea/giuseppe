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
	jvm.new_java_class params.first.jvmclass.class_name
end

def Java_lang_jni_String_valueOf jvm, params
	jvm.new_java_string params.first.to_s
end

def Java_lang_jni_Integer_parseInt jvm, params
	jvm.java_to_native_string(params.first).to_i
end

def Java_lang_jni_Class_isInterface jvm, params
	reference = params.first
	field = JavaField.new(reference.jvmclass, 'name', 'Ljava/lang/String;')
	nameref = jvm.get_field(reference, field)
	jvmclass = jvm.load_class(jvm.java_to_native_string(nameref))
	!jvmclass.array? && jvmclass.class_file.access_flags.interface? ? 1 : 0
end

def Java_lang_jni_Throwable_fillInStackTrace jvm, params
	reference = params.first
	elem_class_type = 'java/lang/StackTraceElement'
	array_class_type = "[L#{elem_class_type};"
	stacktrace = []
	jvmclass = jvm.load_class elem_class_type
	frame = jvm.current_frame
	while frame
		break if frame.method.jvmclass.class_type == reference.jvmclass.class_type
		frame = frame.parent_frame
	end
	frame = frame.parent_frame
	while frame
		stacktrace << jvm.new_java_object_with_constructor(
				JavaMethod.new(
						jvmclass,
						'<init>',
						'(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;I)V'
				),
				[jvm.new_java_string(frame.method.jvmclass.class_name),
					jvm.new_java_string(frame.method.method_name),
					jvm.new_java_string(frame.method.jvmclass.source_file),
					if frame.native? then 0 else frame.code_attr.line_number_for(frame.pc) end]
		)
		frame = frame.parent_frame
	end
	arrayref = jvm.new_java_array(jvm.load_class(array_class_type), [stacktrace.size])
	stacktrace.each_with_index { |s, i| arrayref.values[i] = s }
	method = JavaMethod.new(reference.jvmclass, 'setStackTrace', "(#{array_class_type})V")
	jvm.run method, [reference, arrayref]
	reference
end
