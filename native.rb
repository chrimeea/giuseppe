def Java_lang_jni_System_1_write jvm, params
	print params[1].values.pack('c*')
end

def Java_lang_jni_System_2_write jvm, params
	STDERR.print params[1].values.pack('c*')
end

def Java_lang_jni_System_arraycopy jvm, params	
	src, srcpos, dst, dstpos, length = params
	dst.values[dstpos...(dstpos + length)] = src.values[srcpos...(srcpos + length)]
end

def Java_lang_jni_Object_hashCode jvm, params
	params.first.hash
end

def Java_lang_jni_Object_getClass jvm, params
	jvm.new_java_class params.first.class_type
end

def Java_lang_jni_String_valueOf jvm, params
	jvm.new_java_string params.first.to_s
end

def Java_lang_jni_Throwable_fillInStackTrace jvm, params
	reference = params.first
	elem_class_type = 'java/lang/StackTraceElement'
	array_class_type = "[L#{elem_class_type};"
	elem_jvmclass = jvm.load_class(elem_class_type)
	stacktrace = []
	jvm.frames.each_with_index do |f, i|
		break if f.jvmclass.class_file.this_class_type == reference.class_type
		elementref = jvm.new_java_object elem_class_type
		jvm.run Frame.new(elem_jvmclass,
			JVMMethod.new('<init>',
				'(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;I)V'),
			[elementref,
				jvm.new_java_string(f.jvmclass.class_file.this_class_type),
				jvm.new_java_string(f.method.method_name),
				jvm.new_java_string(f.jvmclass.class_file.source_file),
				f.code_attr.line_number_for_pc(f.pc)])
		stacktrace << elementref
	end
	arrayref = JavaInstanceArray.new(array_class_type, [stacktrace.size])
	stacktrace.reverse.each_with_index { |s, i| arrayref.values[i] = s }
	method = JVMMethod.new('setStackTrace', "(#{array_class_type})V")
	jvm.run Frame.new(jvm.resolve_method(jvm.load_class(reference.class_type), method),
		method,
		[reference, arrayref])
	return reference
end