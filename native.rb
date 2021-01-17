def Java_lang_jni_System_1_write jvm, params
	puts params[1].values.pack('c*')
end

def Java_lang_jni_Throwable_fillInStackTrace jvm, params
	elem_class_type = 'java/lang/StackTraceElement'
	array_class_type = "[L#{elem_class_type};"
	elem_jvmclass = jvm.load_class(elem_class_type)
	arrayref = JavaInstanceArray.new(array_class_type, [jvm.frames.size])
	jvm.frames.each_with_index do |f, i|
		elementref = jvm.new_object elem_class_type
		run Frame.new(elem_jvmclass,
			JVMMethod.new('<init>',
				'(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;I)V'),
			[elementref,
				jvm.new_string(f.jvmclass.class_file.this_class_type),
				jvm.new_string(f.method.method_name),
				nil,
				0])
		arrayref.values[i] = elementref
	end
	reference = params.first
	method = JVMMethod.new('setStackTrace', "(#{array_class_type})V")
	run Frame.new(jvm.resolve_method(jvm.load_class(reference.class_type), method),
		method,
		[reference, arrayref])
	return reference
end