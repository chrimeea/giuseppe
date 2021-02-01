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

def Java_lang_jni_Object_getClass _, params
	jvm.new_java_class params.first.class_type
end

def Java_lang_jni_String_valueOf jvm, params
	jvm.new_java_string params.first.to_s
end

def Java_lang_jni_Integer_parseInt jvm, params
	jvm.java_to_native_string(params.first).to_i
end

def Java_lang_jni_Class_isInterface jvm, params
	reference = params.first
	field = JVMField.new('name', 'Ljava/lang/String;')
	nameref = reference.get_field(jvm.resolve_field(jvm.load_class(reference.class_type), field), field)
	begin
		jvm.load_class(jvm.java_to_native_string(nameref)).class_file.access_flags.interface? ? 1 : 0
	rescue Errno::ENOENT
		0
	end
end

def Java_lang_jni_Throwable_fillInStackTrace jvm, params
	reference = params.first
	elem_class_type = 'java/lang/StackTraceElement'
	array_class_type = "[L#{elem_class_type};"
	stacktrace = []
	jvm.frames.each do |f|
		break if f.jvmclass.class_file.this_class_type == reference.class_type
		stacktrace << jvm.new_java_object_with_constructor(elem_class_type, 
			JVMMethod.new('<init>',
			'(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;I)V'),
			[jvm.new_java_string(f.jvmclass.class_file.this_class_type),
				jvm.new_java_string(f.method.method_name),
				jvm.new_java_string(f.jvmclass.class_file.source_file),
				f.code_attr.line_number_for_pc(f.pc)])
	end
	arrayref = JavaInstanceArray.new(array_class_type, [stacktrace.size])
	stacktrace.reverse.each_with_index { |s, i| arrayref.values[i] = s }
	method = JVMMethod.new('setStackTrace', "(#{array_class_type})V")
	jvm.run Frame.new(jvm.resolve_method(jvm.load_class(reference.class_type), method),
		method,
		[reference, arrayref])
	return reference
end