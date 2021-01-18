def Java_lang_jni_System_1_write jvm, params
	print params[1].values.pack('c*')
end

def Java_lang_jni_System_2_write jvm, params
	STDERR.print params[1].values.pack('c*')
end

def Java_lang_jni_System_arraycopy jvm, params	
	src = params[0]
	srcpos = params[1]
	dst = params[2]
	dstpos = params[3]
	length = params[4]
	dst.values[dstpos...(dstpos + length)] = src.values[srcpos...(srcpos + length)]
end

def Java_lang_jni_Object_hashCode jvm, params
	params.first.hash
end

def Java_lang_jni_Object_toString jvm, params
	reference = params.first
	method = JVMMethod.new('getClass', '()Ljava/lang/Class;')
	class_reference = jvm.run Frame.new(
		jvm.resolve_method(jvm.load_class(reference.class_type), method),
		method,
		[reference])
	name_reference = jvm.run Frame.new(jvm.load_class(class_reference.class_type),
		JVMMethod.new('getName', '()Ljava/lang/String;'),
		[class_reference])
	id_reference = jvm.new_java_string("@#{params.first.object_id.to_s(16)}")
	jvm.run Frame.new(jvm.load_class(name_reference.class_type),
		JVMMethod.new('concat', '(Ljava/lang/String;)Ljava/lang/String;'),
		[name_reference, id_reference])
end

def Java_lang_jni_Object_getClass jvm, params
	jvm.new_java_class params.first.class_type
end

def Java_lang_jni_Throwable_fillInStackTrace jvm, params
	elem_class_type = 'java/lang/StackTraceElement'
	array_class_type = "[L#{elem_class_type};"
	elem_jvmclass = jvm.load_class(elem_class_type)
	arrayref = JavaInstanceArray.new(array_class_type, [jvm.frames.size])
	jvm.frames.each_with_index do |f, i|
		elementref = jvm.new_java_object elem_class_type
		jvm.run Frame.new(elem_jvmclass,
			JVMMethod.new('<init>',
				'(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;I)V'),
			[elementref,
				jvm.new_java_string(f.jvmclass.class_file.this_class_type),
				jvm.new_java_string(f.method.method_name),
				nil,
				0])
		arrayref.values[i] = elementref
	end
	reference = params.first
	method = JVMMethod.new('setStackTrace', "(#{array_class_type})V")
	jvm.run Frame.new(jvm.resolve_method(jvm.load_class(reference.class_type), method),
		method,
		[reference, arrayref])
	return reference
end