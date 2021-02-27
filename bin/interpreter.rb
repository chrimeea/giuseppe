class JVMError < StandardError
	attr_reader :exception

	def initialize exception
		@exception = exception
		super
	end
end

class Interpreter
	def initialize jvm, frame
		@jvm = jvm
		@frame = frame
	end

	def op_aconst value
		@frame.stack.push value
	end

	def case_array opcode
		case opcode
		when 188
			op_newarray
		when 189
			op_anewarray
		when 190
			op_arraylength
		when 197
			op_multianewarray
		end
	end

	def case_field opcode
		case opcode
		when 178
			op_getstatic
		when 179
			op_putstatic
		when 180
			op_getfield
		when 181
			op_putfield
		end
	end

	def case_goto opcode
		case opcode
		when 153
			@frame.goto_if { @frame.stack.pop.zero? }
		when 154
			@frame.goto_if { @frame.stack.pop.nonzero? }
		when 155
			@frame.goto_if { @frame.stack.pop.negative? }
		when 156
			@frame.goto_if { @frame.stack.pop >= 0 }
		when 157
			@frame.goto_if { @frame.stack.pop.positive? }
		when 158
			@frame.goto_if { @frame.stack.pop <= 0 }
		when 159
			@frame.goto_if { @frame.stack.pop == @frame.stack.pop }
		when 160
			@frame.goto_if { @frame.stack.pop != @frame.stack.pop }
		when 161
			@frame.goto_if { @frame.stack.pop > @frame.stack.pop }
		when 162
			@frame.goto_if { @frame.stack.pop <= @frame.stack.pop }
		when 163
			@frame.goto_if { @frame.stack.pop < @frame.stack.pop }
		when 164
			@frame.goto_if { @frame.stack.pop >= @frame.stack.pop }
		when 165
			@frame.goto_if { @frame.stack.pop == @frame.stack.pop }
		when 166
			@frame.goto_if { @frame.stack.pop != @frame.stack.pop }
		when 167
			@frame.goto_if { true }
		when 198
			@frame.goto_if { @frame.stack.pop.nil? }
		when 199
			@frame.goto_if { @frame.stack.pop }
		end
	end

	def case_conversion opcode
		case opcode
		when 133, 141
		when 134, 135, 137, 138
			op_i2f
		when 136, 139, 140
			op_f2i
		when 145
			op_i2b
		when 146
			op_i2c
		when 147
			op_i2s
		end
	end

	def case_boolean opcode
		case opcode
		when 126
			op_iand
		when 128
			op_ior
		when 130
			op_ixor
		end
	end

	def case_ish opcode
		case opcode
		when 120
			op_ishl
		when 122
			op_ishr
		end
	end

	def case_math opcode
		case opcode
		when 96, 97, 98, 99
			op_iadd
		when 100, 101, 102, 103
			op_isub
		when 104, 105, 106, 107
			op_imul
		when 108, 109, 110, 111
			op_idiv
		end
	end

	def case_istore opcode
		case opcode
		when 54, 56, 58
			op_istore @frame.next_instruction
		when 55, 57
			op_lstore @frame.next_instruction
		when 59, 67, 75
			op_istore 0
		when 60, 68, 76
			op_istore 1
		when 61, 69, 77
			op_istore 2
		when 62, 70, 78
			op_istore 3
		when 63, 71
			op_lstore 0
		when 64, 72
			op_lstore 1
		when 65, 73
			op_lstore 2
		when 66, 74
			op_lstore 3
		when 79, 83, 84
			op_iastore
		end
	end

	def case_iload opcode
		case opcode
		when 16
			op_bipush
		when 18
			op_ldc
		when 20
			op_ldc2_wide
		when 21, 22, 23, 24, 25
			op_iload @frame.next_instruction
		when 26, 30, 34, 38, 42
			op_iload 0
		when 27, 31, 35, 39, 43
			op_iload 1
		when 28, 32, 36, 40, 44
			op_iload 2
		when 29, 33, 37, 41, 45
			op_iload 3
		when 46, 50, 51
			op_iaload
		end
	end

	def case_aconst opcode
		case opcode
		when 1
			op_aconst nil
		when 2
			op_aconst(-1)
		when 3, 9
			op_aconst 0
		when 4, 10
			op_aconst 1
		when 5
			op_aconst 2
		when 6
			op_aconst 3
		when 7
			op_aconst 4
		when 8
			op_aconst 5
		when 11, 14
			op_aconst 0.0
		when 12, 15
			op_aconst 1.0
		when 13
			op_aconst 2.0
		end
	end

	def op_bipush
		@frame.stack.push BinaryParser.to_signed(@frame.next_instruction, 1)
	end

	def op_ldc
		index = @frame.next_instruction
		attrib = @frame.jvmclass.class_file.constant_pool[index]
		case attrib
		when ConstantPoolConstantValueInfo
			@frame.stack.push attrib.value
		when ConstantPoolConstantIndex1Info
			value = @frame.jvmclass.class_file.constant_pool[attrib.index1].value
			if attrib.string?
				reference = @jvm.new_java_string(value)
				method = JavaMethod.new('intern', '()Ljava/lang/String;')
				@frame.stack.push @jvm.run_and_return(reference.jvmclass, method, [reference])
			else
				@frame.stack.push @jvm.new_java_class(value)
			end
		else
			fail 'Illegal attribute type'
		end
	end

	def op_ldc2_wide
		index = BinaryParser.to_16bit_unsigned(
				@frame.next_instruction,
				@frame.next_instruction
		)
		@frame.stack.push @frame.jvmclass.class_file.constant_pool[index].value
	end

	def op_iload index
		@frame.stack.push @frame.locals[index]
	end

	def op_lstore index
		@frame.locals[index] = @frame.locals[index + 1] = @frame.stack.pop
	end

	def op_istore index
		@frame.locals[index] = @frame.stack.pop
	end

	def op_iaload
		index = @frame.stack.pop
		arrayref = @frame.stack.pop
		@jvm.check_array_index arrayref, index
		@frame.stack.push arrayref.values[index]
	end

	def op_iastore
		value = @frame.stack.pop
		index = @frame.stack.pop
		arrayref = @frame.stack.pop
		@jvm.check_array_index arrayref, index
		arrayref.values[index] = value
	end

	def op_dup
		@frame.stack.push @frame.stack.last
	end

	def op_iadd
		@frame.stack.push(@frame.stack.pop + @frame.stack.pop)
	end

	def op_isub
		v2 = @frame.stack.pop
		v1 = @frame.stack.pop
		@frame.stack.push v1 - v2
	end

	def op_imul
		@frame.stack.push(@frame.stack.pop * @frame.stack.pop)
	end

	def op_idiv
		v2 = @frame.stack.pop
		v1 = @frame.stack.pop
		@frame.stack.push v1 / v2
	end

	def op_ishl
		v2 = @frame.stack.pop & 31
		v1 = @frame.stack.pop
		@frame.stack.push(v1 << v2)
	end

	def op_ishr
		v2 = @frame.stack.pop & 31
		v1 = @frame.stack.pop
		@frame.stack.push(v1 >> v2)
	end

	def op_iand
		@frame.stack.push(@frame.stack.pop & @frame.stack.pop)
	end

	def op_ior
		@frame.stack.push(@frame.stack.pop | @frame.stack.pop)
	end

	def op_ixor
		@frame.stack.push(@frame.stack.pop ^ @frame.stack.pop)
	end

	def op_iinc
		index = @frame.next_instruction
		value = @frame.next_instruction
		@frame.locals[index] += BinaryParser.to_signed(value, 1)
	end

	def op_i2b
		@frame.stack.push BinaryParser.to_signed(BinaryParser.trunc_to(@frame.stack.pop, 1), 1)
	end

	def op_i2c
		@frame.stack.push BinaryParser.trunc_to(@frame.stack.pop, 1)
	end

	def op_i2s
		@frame.stack.push BinaryParser.to_signed(BinaryParser.trunc_to(@frame.stack.pop, 2), 2)
	end

	def op_i2f
		@frame.stack.push @frame.stack.pop.to_f
	end

	def op_f2i
		@frame.stack.push @frame.stack.pop.to_i
	end

	def op_getstatic
		field_index = BinaryParser.to_16bit_unsigned(
				@frame.next_instruction,
				@frame.next_instruction
		)
		details = @frame.jvmclass.class_file.class_and_name_and_type(field_index)
		field = JavaField.new(details.field_name, details.field_type)
		@frame.stack.push @jvm.get_static_field(@jvm.load_class(details.class_type), field)
	end

	def op_putstatic
		field_index = BinaryParser.to_16bit_unsigned(
				@frame.next_instruction,
				@frame.next_instruction
		)
		details = @frame.jvmclass.class_file.class_and_name_and_type(field_index)
		field = JavaField.new(details.field_name, details.field_type)
		@jvm.set_static_field(@jvm.load_class(details.class_type), field, @frame.stack.pop)
	end

	def op_getfield
		field_index = BinaryParser.to_16bit_unsigned(
				@frame.next_instruction,
				@frame.next_instruction
		)
		details = @frame.jvmclass.class_file.class_and_name_and_type(field_index)
		reference = @frame.stack.pop
		field = JavaField.new(details.field_name, details.field_type)
		@frame.stack.push @jvm.get_field(reference, @jvm.load_class(details.class_type), field)
	end

	def op_putfield
		field_index = BinaryParser.to_16bit_unsigned(
				@frame.next_instruction,
				@frame.next_instruction
		)
		details = @frame.jvmclass.class_file.class_and_name_and_type(field_index)
		value = @frame.stack.pop
		reference = @frame.stack.pop
		field = JavaField.new(details.field_name, details.field_type)
		@jvm.set_field(reference, @jvm.load_class(details.class_type), field, value)
	end

	def op_invoke opcode
		method_index = BinaryParser.to_16bit_unsigned(
				@frame.next_instruction,
				@frame.next_instruction
		)
		details = @frame.jvmclass.class_file.class_and_name_and_type(method_index)
		method = JavaMethod.new(details.field_name, details.field_type)
		params = []
		args_count = method.args.size
		args_count.times { params.push @frame.stack.pop }
		if opcode == 184
			jvmclass = @jvm.resolve_method(@jvm.load_class(details.class_type), method)
		else
			reference = @frame.stack.pop
			params.push reference
			jvmclass =  if opcode == 183
							@jvm.resolve_special_method(
									reference.jvmclass,
									@jvm.load_class(details.class_type),
									method
							)
						else
							@jvm.resolve_method(reference.jvmclass, method)
						end
		end
		if opcode == 185
			@frame.next_instruction
			@frame.next_instruction
		end
		@jvm.run jvmclass, method, params.reverse
	end

	def op_newobject
		class_index = BinaryParser.to_16bit_unsigned(
				@frame.next_instruction,
				@frame.next_instruction
		)
		@frame.stack.push @jvm.new_java_object(@jvm.load_class(@frame.jvmclass.class_file.get_attrib_name(class_index)))
	end

	def op_newarray
		count = @frame.stack.pop
		array_code = @frame.next_instruction
		array_type = [nil, nil, nil, nil, '[Z', '[C', '[F', '[D', '[B', '[S', '[I', '[J']
		@frame.stack.push @jvm.new_java_array(@jvm.load_class(array_type[array_code]), [count])
	end

	def op_anewarray
		class_index = BinaryParser.to_16bit_unsigned(
				@frame.next_instruction,
				@frame.next_instruction
		)
		array_type = "[#{@frame.jvmclass.class_file.get_attrib_name(class_index)}"
		count = @frame.stack.pop
		@frame.stack.push @jvm.new_java_array(@jvm.load_class(array_type), [count])
	end

	def op_arraylength
		array_reference = @frame.stack.pop
		@frame.stack.push array_reference.values.size
	end

	def op_athrow
		raise JVMError, @frame.stack.pop
	end

	def op_checkcast
		class_index = BinaryParser.to_16bit_unsigned(
				@frame.next_instruction,
				@frame.next_instruction
		)
		reference = @frame.stack.last
		if reference && !@jvm.type_equal_or_superclass?(reference.jvmclass, @jvm.load_class(@frame.jvmclass.class_file.get_attrib_name(class_index)))
			raise JVMError, @jvm.new_java_object_with_constructor(@jvm.load_class('java/lang/ClassCastException'))
		end
	end

	def op_instanceof
		class_index = BinaryParser.to_16bit_unsigned(
				@frame.next_instruction,
				@frame.next_instruction
		)
		reference = @frame.stack.pop
		if reference
			@frame.stack.push(@jvm.type_equal_or_superclass?(reference.jvmclass,
				@jvm.load_class(@frame.jvmclass.class_file.get_attrib_name(class_index))) ? 1 : 0)
		else
			@frame.stack.push 0
		end
	end

	def op_multianewarray
		class_index = BinaryParser.to_16bit_unsigned(
				@frame.next_instruction,
				@frame.next_instruction
		)
		dimensions = @frame.next_instruction
		counts = []
		dimensions.times { counts << @frame.stack.pop }
		@frame.stack.push @jvm.new_java_array(
				@jvm.load_class(@frame.jvmclass.class_file.get_attrib_name(class_index)),
				counts.reverse
		)
	end

	def loop_code
		$logger.debug('interpreter.rb') do
			"#{@jvm.frames.size}, #{@frame.code_attr.code}"
		end
		while @frame.pc < @frame.code_attr.code.length
			begin
				opcode = @frame.next_instruction
				$logger.debug('interpreter.rb') do
					"#{@jvm.frames.size}, #{opcode}"
				end
				case opcode
				when 0
				when 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
					case_aconst opcode
				when 16, 18, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 50, 51
					case_iload opcode
				when 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 83, 84
					case_istore opcode
				when 87
					@frame.stack.pop
				when 89
					op_dup
				when 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111
					case_math opcode
				when 120, 122
					case_ish opcode
				when 126, 128, 130
					case_boolean opcode
				when 132
					op_iinc
				when 133, 134, 135, 136, 137, 138, 139, 140, 141, 145, 146, 147
					case_conversion opcode
				when 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 198, 199
					case_goto opcode
				when 172, 176
					return @frame.stack.pop
				when 177
					break
				when 178, 179, 180, 181
					case_field opcode
				when 182, 183, 184, 185
					op_invoke opcode
				when 187
					op_newobject
				when 188, 189, 190, 197
					case_array opcode
				when 191
					op_athrow
				when 192
					op_checkcast
				when 193
					op_instanceof
				else
					fail "Unsupported opcode #{opcode}"
				end
			rescue JVMError => e
				handle_exception e.exception
			rescue ZeroDivisionError
				handle_exception @jvm.new_java_object_with_constructor(@jvm.load_class('java/lang/ArithmeticException'))
			rescue NoMethodError => e
				raise e if e.receiver
				handle_exception @jvm.new_java_object_with_constructor(@jvm.load_class('java/lang/NullPointerException'))
			end
		end
	end

	def handle_exception exception
		handler = resolve_exception_handler exception
		raise JVMError, exception unless handler
		@frame.stack.push exception
		@frame.pc = handler.handler_pc
	end

	def resolve_exception_handler exception
		@frame.code_attr.exception_table.each do |e|
			if @frame.pc - 1 >= e.start_pc && @frame.pc - 1 < e.end_pc &&
				(e.catch_type.zero? ||
				@jvm.type_equal_or_superclass?(exception.jvmclass,
					@jvm.load_class(@frame.jvmclass.class_file.get_attrib_name(e.catch_type))))
				return e
			end
		end
		nil
	end
end
