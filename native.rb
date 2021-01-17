def Java_lang_jni_System_1_write jvm, params
	puts params[1].values.pack('c*')
end

def Java_lang_jni_Throwable_fillInStackTrace jvm, params
	elem_class_type = 'java/lang/StackTraceElement'
	array_class_type = "[L#{class_type};"
	elem_jvmclass = jvm.load_class(elem_class_type)
	arrayref = JavaInstanceArray.new(array_class_type, [jvm.frames.size])
	v = []
	jvm.frames.each do |f|
		elementref = jvm.new_object elem_class_type
		run Frame.new(elem_jvmclass,
			JVMMethod.new('<init>',
				'(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;I)V'),
			[elementref,
				jvm.new_string(f.jvmclass.class_file.this_class_type),
				jvm.new_string(f.method.method_name),
				nil,
				0])
		v << elementref
	end
	arrayref.values = v
	throwableref = params.first
	throwable_jvmclass = jvm.load_class(throwableref.class_type)
	run Frame.new(throwable_jvmclass,
		JVMMethod.new('setStackTrace', "(#{array_class_type})V"),
		[throwableref, arrayref])
	return throwableref
end