module DiffJson
  class Diff
    def initialize(old_json, new_json, **opts)
      @old_json   = old_json
      @new_json   = new_json
      @calculated = false
      @diff = {
        :old => [],
        :new => []
      }
    end

    def output(output_type = :stdout)
      calculate unless @calculated

      case output_type
      when :raw
        return @diff
      when :stdout
      when :file
      when :html
      end
    end

    private

    def calculate
      puts [
        '----------------------',
        'ENTER DIFF CALCULATION',
        '----------------------',
        ''
      ]
      @diff[:old], @diff[:new] = compare_elements(@old_json, @new_json)
    end

    def compare_elements(old_element, new_element, indent_step = 0)
      puts [
        'DEBUG -- Enter compare_elements',
        '',
        'Old Element ->'
      ]
      pp(old_element)
      puts [
        '',
        'New Element ->'
      ]
      pp(new_element)
      puts ''

      old_element_lines, new_element_lines = [], []

      if old_element == new_element
        element_lines_arr = JSON.pretty_generate(old_element).split("\n").map{|el| [' ', "#{indentation(indent_step)}#{el}"]}
        old_element_lines = element_lines_arr
        new_element_lines = element_lines_arr
      else
        unless value_type(old_element) == value_type(new_element)
          old_element_lines, new_element_lines = add_blank_lines(
            JSON.pretty_generate(old_element).split("\n").map{|el| ['-', "#{indentation(indent_step)}#{el}"]},
            JSON.pretty_generate(new_element).split("\n").map{|el| ['+', "#{indentation(indent_step)}#{el}"]}
          )
        else
          old_element_lines, new_element_lines = self.send("#{value_type(old_element)}_diff", old_element, new_element, (indent_step + 1))
        end
      end

      return old_element_lines, new_element_lines
    end

    def array_diff(old_array, new_array, indent_step)
      puts [
        'DEBUG -- Enter array_diff',
        '',
        'Old Array ->'
      ]
      pp(old_array)
      puts [
        '',
        'New Array ->'
      ]
      pp(new_array)
      puts ''

      oal, nal   = old_array.length, new_array.length
      sal        = oal < nal ? oal : nal
      lal        = oal > nal ? oal : nal
      old_array_lines, new_array_lines = [[' ', "#{indentation(indent_step)}["]], [[' ', "#{indentation(indent_step)}["]]
      operations = {
        'none'             => [],
        'arr_add_index'    => [],
        'arr_drop_index'   => [],
        'arr_send_move'    => [],
        'arr_receive_move' => []
      }

      # Find indices that were added or dropped, if any
      if oal < nal
        operations['arr_add_index'] += (oal..(nal - 1)).to_a
      elsif oal > nal
        operations['arr_drop_index'] += (nal..(oal - 1)).to_a
      end

      # Find 'none' and 'move_value' operations
      (old_array | new_array).each do |v|
        # For a given value, find all indices of each array that corresponds
        old_indices, new_indices = array_indices(old_array, v), array_indices(new_array, v)
        # Same index, same value, no diff necessary
        operations['none'] += (old_indices & new_indices)

        # Pull the skipped indices before calculating movements
        old_indices -= operations['none']
        new_indices -= operations['none']

        # Find values that were moved from one index to another
        if !old_indices.empty? and !new_indices.empty?
          max_moves = old_indices.length < new_indices.length ? old_indices.length : new_indices.length
          possible_moves = []
          # Make pairs of possible moves
          old_indices.each do |oi|
            new_indices.each do |ni|
              possible_moves << [(oi - ni).abs, [oi, ni]]
            end
          end
          # For the sake of simplicity, we'll arbitrarily decide to use the shortest moves
          possible_moves.sort!{|x,y| x[0] <=> y[0]}
          # Take the first (max_moves) moves and add their operations
          possible_moves[0..(max_moves - 1)].each do |move|
            operations['arr_send_move'] << move[1][0]
            operations['arr_receive_move'] << move[1][1]
          end
        end
      end

      # Add base diff for each index
      (0..(lal - 1)).each do |i|
        puts [
          "DEBUG -- processing array index #{i}",
          ''
        ]

        old_item_lines, new_item_lines = [], []
        item_diff_operations = []
        last_loop = (i == (lal - 1))

        # Assign current known operations to each index
        (operations.keys).each do |operation|
          if operations[operation].include?(i)
            item_diff_operations << operation
          end
        end

        # Add arr_change_value, arr_add_value, and arr_drop_value operations
        if item_diff_operations.empty?
          item_diff_operations << 'arr_change_value'
        elsif (
          item_diff_operations.include?('arr_send_move') and
          !item_diff_operations.include?('arr_receive_move') and
          !item_diff_operations.include?('arr_drop_index')
        )
          item_diff_operations << 'arr_add_value'
        elsif (
          !item_diff_operations.include?('arr_send_move') and
          item_diff_operations.include?('arr_receive_move') and
          !item_diff_operations.include?('arr_add_index')
        )
          item_diff_operations << 'arr_drop_value'
        end

        puts [
          'DEBUG -- item operations',
          item_diff_operations,
          ''
        ]

        # Call compare_elements for sub-elements if necessary
        if (!(item_diff_operations & ['none', 'arr_change_value']).empty? and
          is_json_element?(old_array[i]) and is_json_element?(new_array[i])
        )
          old_item_lines, new_item_lines = compare_elements(old_array[i], new_array[i], (indent_step))
        else
          # Grab old and new items
          # UndefinedValue class is here to represent the difference between explicit null and non-existent
          old_item = item_diff_operations.include?('arr_add_index') ? UndefinedValue.new : old_array[i]
          new_item = item_diff_operations.include?('arr_drop_index') ? UndefinedValue.new : new_array[i]

          # Figure out operators for left and right
          if item_diff_operations.include?('none')
            old_operator, new_operator = ' '
          elsif item_diff_operations.include?('arr_change_value')
            old_operator, new_operator = '-', '+'
          elsif (item_diff_operations & ['arr_send_move', 'arr_receive_move']).length == 2
            old_operator, new_operator = 'M', 'M'
          elsif item_diff_operations.include?('arr_add_value')
            old_operator, new_operator = 'M', '+'
          elsif item_diff_operations.include?('arr_drop_value')
            old_operator, new_operator = '-', 'M'
          elsif item_diff_operations.include?('arr_drop_index')
            if item_diff_operations.include?('arr_send_move')
              old_operator, new_operator = 'M', ' '
            else
              old_operator, new_operator = '-', ' '
            end
          elsif item_diff_operations.include?('arr_add_index')
            if item_diff_operations.include?('arr_receive_move')
              old_operator, new_operator = ' ', 'M'
            else
              old_operator, new_operator = ' ', '+'
            end
          end

          puts [
            'DEBUG -- operators',
            old_operator.inspect,
            new_operator.inspect,
            ''
          ]

          # Gather lines
          if old_item.is_a?(UndefinedValue)
            new_item_lines = JSON.pretty_generate(new_item).split("\n").map{|il| [new_operator, "#{indentation(indent_step + 1)}#{il}"]}

            (0..(new_item_lines.length - 1)).each do |i|
              old_item_lines << [' ', '']
            end
          else
            old_item_lines = JSON.pretty_generate(old_item).split("\n").map{|il| [old_operator, "#{indentation(indent_step + 1)}#{il}"]}
          end

          if new_item.is_a?(UndefinedValue)
            (0..(old_item_lines.length - 1)).each do |i|
              new_item_lines << [' ', '']
            end
          else
            new_item_lines = JSON.pretty_generate(new_item).split("\n").map{|il| [new_operator, "#{indentation(indent_step + 1)}#{il}"]}
          end
        end

        old_item_lines.last[1] = "#{old_item_lines.last[1]}," unless last_loop
        new_item_lines.last[1] = "#{new_item_lines.last[1]}," unless last_loop
        old_item_lines, new_item_lines = add_blank_lines(old_item_lines, new_item_lines)

        old_array_lines += old_item_lines
        new_array_lines += new_item_lines
      end

      old_array_lines << [' ', "#{indentation(indent_step)}]"]
      new_array_lines << [' ', "#{indentation(indent_step)}]"]

      return old_array_lines, new_array_lines
    end

    def object_diff(old_object, new_object, indent_step)
      puts [
        'DEBUG -- Enter object_diff',
        '',
        'Old Object ->'
      ]
      pp(old_object)
      puts [
        '',
        'New Object ->'
      ]
      pp(new_object)
      puts ''

      keys = {
        'all'    => (old_object.keys | new_object.keys),
        'common' => (old_object.keys & new_object.keys),
        'add'    => (new_object.keys - old_object.keys),
        'drop'   => (old_object.keys - new_object.keys)
      }
      old_object_lines, new_object_lines = [[' ', "#{indentation(indent_step)}{"]], [[' ', "#{indentation(indent_step)}{"]]

      # For objects, we're taking a much simpler approach, so no movements
      keys['all'].each do |k|
        puts [
          "DEBUG -- processing object key #{k}",
          ''
        ]

        old_item_lines, new_item_lines = [], []
        last_loop = (k == keys['all'].last)

        if keys['common'].include?(k)
          if is_json_element?(old_object[k]) and is_json_element?(new_object[k])
            old_item_lines, new_item_lines = compare_elements(old_object[k], new_object[k], (indent_step + 1))
            old_item_lines[0][1] = "#{indentation(indent_step + 1)}#{JSON.pretty_generate(k)}: #{old_item_lines[0][1].gsub(/^\s+/, '')}"
            new_item_lines[0][1] = "#{indentation(indent_step + 1)}#{JSON.pretty_generate(k)}: #{new_item_lines[0][1].gsub(/^\s+/, '')}"
          else
            if old_object[k] == new_object[k]
              item_lines = JSON.pretty_generate(old_object[k]).split("\n")
              item_lines[0] = "#{JSON.pretty_generate(k)}: #{item_lines[0]}"
              item_lines.map!{|il| ['|', "#{indentation(indent_step)}#{il}"]}
              old_item_lines = item_lines
              new_item_lines = item_lines
            else
              old_item_lines    = JSON.pretty_generate(old_object[k]).split("\n")
              old_item_lines[0] = "#{JSON.pretty_generate(k)}: #{old_item_lines[0]}"
              old_item_lines.map!{|il| ['-', "#{indentation(indent_step)}#{il}"]}
              new_item_lines    = JSON.pretty_generate(new_object[k]).split("\n")
              new_item_lines[0] = "#{JSON.pretty_generate(k)}: #{new_item_lines[0]}"
              new_item_lines.map!{|il| ['+', "#{indentation(indent_step)}#{il}"]}
            end
          end
        else
          if keys['drop'].include?(k)
            old_item_lines    = JSON.pretty_generate(old_object[k]).split("\n")
            old_item_lines[0] = "#{JSON.pretty_generate(k)}: #{old_item_lines[0]}"
            old_item_lines.map!{|il| ['-', "#{indentation(indent_step)}#{il}"]}
            new_item_lines = []

            (0..(old_item_lines.length - 1)).each do |i|
              new_item_lines << [' ', '']
            end
          else
            new_item_lines    = JSON.pretty_generate(new_object[k]).split("\n")
            new_item_lines[0] = "#{JSON.pretty_generate(k)}: #{new_item_lines[0]}"
            new_item_lines.map!{|il| ['-', "#{indentation(indent_step)}#{il}"]}
            old_item_lines = []

            (0..(new_item_lines.length - 1)).each do |i|
              old_item_lines << [' ', '']
            end
          end
        end

        puts [
          'DEBUG -- old item lines',
          old_item_lines,
          'DEBUG -- new item lines',
          new_item_lines
        ]

        old_item_lines.last[1] = "#{old_item_lines.last[1]}," unless last_loop
        new_item_lines.last[1] = "#{new_item_lines.last[1]}," unless last_loop
        old_item_lines, new_item_lines = add_blank_lines(old_item_lines, new_item_lines)

        old_object_lines += old_item_lines
        new_object_lines += new_item_lines
      end

      old_object_lines << [' ', "#{indentation(indent_step)}}"]
      new_object_lines << [' ', "#{indentation(indent_step)}}"]

      return old_object_lines, new_object_lines
    end

    def array_indices(array, value)
      indices = []

      array.each_with_index do |av,i|
        indices << i if av == value
      end

      return indices
    end

    def is_json_element?(object)
      return true if ['array', 'object'].include?(value_type(object))
    end

    def value_type(element)
      case class_name = element.class.name
      when 'Hash'
        return 'object'
      when 'NilClass'
        return 'null'
      when 'TrueClass', 'FalseClass'
        return 'boolean'
      else
        return class_name.downcase
      end
    end

    def indentation(step)
      '  ' * step
    end

    def add_blank_lines(left_lines, right_lines)
      if left_lines.length < right_lines.length
        (1..(right_lines.length - left_lines.length)).each do
          left_lines << [' ', '']
        end
      elsif left_lines.length > right_lines.length
        (1..(left_lines.length - right_lines.length)).each do
          right_lines << [' ', '']
        end
      end

      return left_lines, right_lines
    end
  end
end
