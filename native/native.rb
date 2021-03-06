# frozen_string_literal: true

include Giuseppe

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
	jvm.new_java_class_object params.first.jvmclass.descriptor.class_name
end

def Java_lang_jni_String_valueOf jvm, params
	jvm.new_java_string params.first.to_s
end

def Java_lang_jni_Integer_parseInt jvm, params
	jvm.java_to_native_string(params.first).to_i
end

def Java_lang_jni_Class_isInterface jvm, params
	reference = params.first
	method = JavaMethodHandle.new(reference.jvmclass, 'getName', '()Ljava/lang/String;')
	nameref = jvm.run(method, [reference])
	jvmclass = jvm.java_class(jvm.java_to_native_string(nameref))
	!jvmclass.descriptor.array? && jvmclass.class_file.access_flags.interface? ? 1 : 0
end

def Java_lang_jni_Throwable_fillInStackTrace jvm, params
	reference = params.first
	elem_class_type = 'java/lang/StackTraceElement'
	array_class_type = "[L#{elem_class_type};"
	stacktrace = []
	jvmclass = jvm.java_class elem_class_type
	frame = jvm.current_frame
	frame = frame.parent_frame while !frame.method.jvmclass.eql?(reference.jvmclass)
	loop do
		frame = frame.parent_frame
		break unless frame
		stacktrace << jvm.new_java_object_with_constructor(
				JavaMethodHandle.new(
						jvmclass,
						'<init>',
						'(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;I)V'
				),
				[jvm.new_java_string(frame.method.jvmclass.descriptor.class_name),
					jvm.new_java_string(frame.method.name),
					jvm.new_java_string(frame.method.jvmclass.source_file),
					frame.line_number]
		)
	end
	arrayref = jvm.new_java_array(jvm.java_class(array_class_type), [stacktrace.size])
	stacktrace.each_with_index { |s, i| arrayref.values[i] = s }
	method = JavaMethodHandle.new(reference.jvmclass, 'setStackTrace', "(#{array_class_type})V")
	jvm.run method, [reference, arrayref]
	reference
end
