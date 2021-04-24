# frozen_string_literal: true

module Giuseppe
	# A java exception wrapped as a ruby error
	class JVMError < StandardError
		attr_reader :exception

		def initialize exception
			super
			@exception = exception
		end
	end

	# Implements fields related operations
	class FieldOperations
		def initialize jvm
			@jvm = jvm
			@frame = jvm.current_frame
		end

		def interpret opcode
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

			private

		def op_getstatic
			field_index = BinaryParser.to_16bit_unsigned(
					@frame.next_instruction,
					@frame.next_instruction
			)
			details = @frame.constant_pool.class_and_name_and_type(field_index)
			field = JavaFieldHandle.new(@jvm.load_class(details.class_type), details.field_name, details.field_type)
			@frame.stack.push @jvm.get_static_field(field)
		end

		def op_putstatic
			field_index = BinaryParser.to_16bit_unsigned(
					@frame.next_instruction,
					@frame.next_instruction
			)
			details = @frame.constant_pool.class_and_name_and_type(field_index)
			field = JavaFieldHandle.new(@jvm.load_class(details.class_type), details.field_name, details.field_type)
			@jvm.set_static_field(field, @frame.stack.pop)
		end

		def op_getfield
			field_index = BinaryParser.to_16bit_unsigned(
					@frame.next_instruction,
					@frame.next_instruction
			)
			details = @frame.constant_pool.class_and_name_and_type(field_index)
			reference = @frame.stack.pop
			field = JavaFieldHandle.new(@jvm.load_class(details.class_type), details.field_name, details.field_type)
			@frame.stack.push @jvm.get_field(reference, field)
		end

		def op_putfield
			field_index = BinaryParser.to_16bit_unsigned(
					@frame.next_instruction,
					@frame.next_instruction
			)
			details = @frame.constant_pool.class_and_name_and_type(field_index)
			value = @frame.stack.pop
			reference = @frame.stack.pop
			field = JavaFieldHandle.new(@jvm.load_class(details.class_type), details.field_name, details.field_type)
			@jvm.set_field(reference, field, value)
		end
	end

	# Implements array related operations
	class ArrayOperations
		def initialize jvm
			@jvm = jvm
			@frame = jvm.current_frame
		end

		def interpret opcode
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

			private

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
			array_type = "[#{@frame.constant_pool.get_attrib_value(class_index)}"
			count = @frame.stack.pop
			@frame.stack.push @jvm.new_java_array(@jvm.load_class(array_type), [count])
		end

		def op_arraylength
			array_reference = @frame.stack.pop
			@frame.stack.push array_reference.values.size
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
					@jvm.load_class(@frame.constant_pool.get_attrib_value(class_index)),
					counts.reverse
			)
		end
	end

	# Implements goto operations
	class GotoOperations
		def initialize jvm
			@jvm = jvm
			@frame = jvm.current_frame
		end

		def interpret opcode
			case opcode
			when 153
				op_gotoif { @frame.stack.pop.zero? }
			when 154
				op_gotoif { @frame.stack.pop.nonzero? }
			when 155
				op_gotoif { @frame.stack.pop.negative? }
			when 156
				op_gotoif { @frame.stack.pop >= 0 }
			when 157
				op_gotoif { @frame.stack.pop.positive? }
			when 158
				op_gotoif { @frame.stack.pop <= 0 }
			when 159
				op_gotoif { @frame.stack.pop == @frame.stack.pop }
			when 160
				op_gotoif { @frame.stack.pop != @frame.stack.pop }
			when 161
				op_gotoif { @frame.stack.pop > @frame.stack.pop }
			when 162
				op_gotoif { @frame.stack.pop <= @frame.stack.pop }
			when 163
				op_gotoif { @frame.stack.pop < @frame.stack.pop }
			when 164
				op_gotoif { @frame.stack.pop >= @frame.stack.pop }
			when 165
				op_gotoif { @frame.stack.pop == @frame.stack.pop }
			when 166
				op_gotoif { @frame.stack.pop != @frame.stack.pop }
			when 167
				op_gotoif { true }
			when 198
				op_gotoif { @frame.stack.pop.nil? }
			when 199
				op_gotoif { @frame.stack.pop }
			end
		end

		def op_gotoif
			@frame.pc += if yield
							BinaryParser.to_signed(
									BinaryParser.to_16bit_unsigned(
											@frame.instruction,
											@frame.instruction(+1)
									),
									2
							) - 1
						else
							2
						end
		end
	end

	# Implements type conversion operations
	class ConversionOperations
		def initialize jvm
			@jvm = jvm
			@frame = jvm.current_frame
		end

		def interpret opcode
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

			private

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
	end

	# Implements byte boolean operations
	class BooleanOperations
		def initialize jvm
			@jvm = jvm
			@frame = jvm.current_frame
		end

		def interpret opcode
			case opcode
			when 126
				op_iand
			when 128
				op_ior
			when 130
				op_ixor
			end
		end

			private

		def op_iand
			@frame.stack.push(@frame.stack.pop & @frame.stack.pop)
		end

		def op_ior
			@frame.stack.push(@frame.stack.pop | @frame.stack.pop)
		end

		def op_ixor
			@frame.stack.push(@frame.stack.pop ^ @frame.stack.pop)
		end
	end

	# Implements byte shifting operations
	class ShiftOperations
		def initialize jvm
			@jvm = jvm
			@frame = jvm.current_frame
		end

		def interpret opcode
			case opcode
			when 120
				op_ishl
			when 122
				op_ishr
			end
		end

			private

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
	end

	# Implements math operations
	class MathOperations
		def initialize jvm
			@jvm = jvm
			@frame = jvm.current_frame
		end

		def interpret opcode
			case opcode
			when 96..99
				op_iadd
			when 100..103
				op_isub
			when 104..107
				op_imul
			when 108..111
				op_idiv
			end
		end

			private

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
	end

	# Implements locals operations
	class StoreOperations
		def initialize jvm
			@jvm = jvm
			@frame = jvm.current_frame
		end

		def interpret opcode
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
			when 132
				op_iinc
			end
		end

			private

		def op_iinc
			index = @frame.next_instruction
			value = @frame.next_instruction
			@frame.locals[index] += BinaryParser.to_signed(value, 1)
		end

		def op_lstore index
			@frame.locals[index] = @frame.locals[index + 1] = @frame.stack.pop
		end

		def op_istore index
			@frame.locals[index] = @frame.stack.pop
		end

		def op_iastore
			value = @frame.stack.pop
			index = @frame.stack.pop
			arrayref = @frame.stack.pop
			@jvm.check_array_index arrayref, index
			arrayref.values[index] = value
		end
	end

	# Implements load into stack operations
	class LoadOperations
		def initialize jvm
			@jvm = jvm
			@frame = jvm.current_frame
		end

		def interpret opcode
			case opcode
			when 16
				op_bipush
			when 17
				op_sipush
			when 18
				op_ldc
			when 20
				op_ldc2_wide
			when 21..25
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

			private

		def op_bipush
			@frame.stack.push BinaryParser.to_signed(@frame.next_instruction, 1)
		end

		def op_sipush
			@frame.stack.push BinaryParser.to_signed(
					BinaryParser.to_16bit_unsigned(
							@frame.next_instruction,
							@frame.next_instruction
					),
					2
			)
		end

		def op_ldc
			index = @frame.next_instruction
			attrib = @frame.constant_pool[index]
			case attrib
			when ConstantPoolConstantValueInfo
				@frame.stack.push attrib.value
			when ConstantPoolConstantIndex1Info
				value = @frame.constant_pool[attrib.index1].value
				if attrib.string?
					reference = @jvm.new_java_string(value)
					method = JavaMethodHandle.new(reference.jvmclass, 'intern', '()Ljava/lang/String;')
					@frame.stack.push @jvm.run(method, [reference])
				else
					@frame.stack.push @jvm.new_java_class_object(value)
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
			@frame.stack.push @frame.constant_pool[index].value
		end

		def op_iload index
			@frame.stack.push @frame.locals[index]
		end

		def op_iaload
			index = @frame.stack.pop
			arrayref = @frame.stack.pop
			@jvm.check_array_index arrayref, index
			@frame.stack.push arrayref.values[index]
		end
	end

	# Implements const operations
	class ConstOperations
		def initialize jvm
			@jvm = jvm
			@frame = jvm.current_frame
		end

		def interpret opcode
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

			private

		def op_aconst value
			@frame.stack.push value
		end
	end

	# Implements stack operations
	class StackOperations
		def initialize jvm
			@jvm = jvm
			@frame = jvm.current_frame
		end

		def interpret opcode
			case opcode
			when 87
				@frame.stack.pop
			when 89
				op_dup
			end
		end

			private

		def op_dup
			@frame.stack.push @frame.stack.last
		end
	end

	# Implements object related operations
	class ObjectOperations
		def initialize jvm
			@jvm = jvm
			@frame = jvm.current_frame
		end

		def interpret opcode
			case opcode
			when 182..185
				op_invoke opcode
			when 187
				op_newobject
			when 191
				op_athrow
			when 192
				op_checkcast
			when 193
				op_instanceof
			end
		end

			private

		def op_invoke opcode
			method_index = BinaryParser.to_16bit_unsigned(
					@frame.next_instruction,
					@frame.next_instruction
			)
			details = @frame.constant_pool.class_and_name_and_type(method_index)
			method = JavaMethodHandle.new(@jvm.load_class(details.class_type), details.field_name, details.field_type)
			params = []
			args_count = method.descriptor.args.size
			args_count.times { params.push @frame.stack.pop }
			if opcode != 184
				reference = @frame.stack.pop
				params.push reference
				if opcode == 183
					@jvm.resolve_special_method!(reference.jvmclass, method)
				else
					method.jvmclass = reference.jvmclass
				end
			end
			if opcode == 185
				@frame.next_instruction
				@frame.next_instruction
			end
			result = @jvm.run(method, params.reverse)
			@frame.stack.push result unless method.descriptor.retval.void?
		end

		def op_newobject
			class_index = BinaryParser.to_16bit_unsigned(
					@frame.next_instruction,
					@frame.next_instruction
			)
			@frame.stack.push @jvm.new_java_object(@jvm.load_class(@frame.constant_pool.get_attrib_value(class_index)))
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
			return unless reference &&
					!@jvm.type_equal_or_superclass?(
							reference.jvmclass,
							@jvm.load_class(@frame.constant_pool.get_attrib_value(class_index))
					)
			raise JVMError, @jvm.new_java_object_with_constructor(
					JavaMethodHandle.new(@jvm.load_class('java/lang/ClassCastException'))
			)
		end

		def op_instanceof
			class_index = BinaryParser.to_16bit_unsigned(
					@frame.next_instruction,
					@frame.next_instruction
			)
			reference = @frame.stack.pop
			if reference
				@frame.stack.push(
						if @jvm.type_equal_or_superclass?(
								reference.jvmclass,
								@jvm.load_class(@frame.constant_pool.get_attrib_value(class_index))
						) then 1 else 0 end
				)
			else
				@frame.stack.push 0
			end
		end
	end

	# Matches opcodes with their implementation
	class OperationDispatcher
		def initialize jvm
			@const_ops = ConstOperations.new(jvm)
			@load_ops = LoadOperations.new(jvm)
			@store_ops = StoreOperations.new(jvm)
			@stack_ops = StackOperations.new(jvm)
			@math_ops = MathOperations.new(jvm)
			@shift_ops = ShiftOperations.new(jvm)
			@bool_ops = BooleanOperations.new(jvm)
			@conversion_ops = ConversionOperations.new(jvm)
			@goto_ops = GotoOperations.new(jvm)
			@field_ops = FieldOperations.new(jvm)
			@obj_ops = ObjectOperations.new(jvm)
			@array_ops = ArrayOperations.new(jvm)
		end

		def interpret opcode
			case opcode
			when 0
			when 1..15
				@const_ops.interpret opcode
			when 16..18, 20..46, 50, 51
				@load_ops.interpret opcode
			when 54..79, 83, 84, 132
				@store_ops.interpret opcode
			when 87, 89
				@stack_ops.interpret opcode
			when 96..111
				@math_ops.interpret opcode
			when 120, 122
				@shift_ops.interpret opcode
			when 126, 128, 130
				@bool_ops.interpret opcode
			when 133..141, 145, 146, 147
				@conversion_ops.interpret opcode
			when 153..167, 198, 199
				@goto_ops.interpret opcode
			when 178..181
				@field_ops.interpret opcode
			when 182..185, 187, 191..193
				@obj_ops.interpret opcode
			when 188..190, 197
				@array_ops.interpret opcode
			else
				fail "Unsupported opcode #{opcode}"
			end
		end
	end
end
