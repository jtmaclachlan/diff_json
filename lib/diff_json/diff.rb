module DiffJson
  class Diff
    def initialize(old_json, new_json, **opts)
      @old_json   = old_json
      @new_json   = new_json
      @opts       = {
        :debug              => false,
        :diff_count_filter  => {
          :only   => ['$**'],
          :except => []
        },
        :ignore_object_keys        => [],
        :generate_object_sub_diffs => {}
      }.merge(opts)
      @filtered = @opts[:diff_count_filter] != {
        :only   => ['$**'],
        :except => []
      }
      @diff = {
        :count => {
          :all    => 0,
          :insert => 0,
          :update => 0,
          :delete => 0,
          :move   => 0
        },
        :full_diff => {
          :old   => [],
          :new   => []
        },
        :sub_diffs => {}
      }

      calculate
    end

    def diff
      return @diff
    end

    def retrieve_output(output_type = :stdout, **output_opts)
      case output_type
      when :stdout
      when :file
      when :html
        html_output = HtmlOutput.new(@diff, **output_opts)
        return html_output
      end
    end

    private

    def calculate
      @diff[:full_diff][:old], @diff[:full_diff][:new] = compare_elements(@old_json, @new_json)

      @diff[:sub_diffs].each do |key, sub_diffs|
        sub_diffs.each do |value, diff|
          diff[:old] = [] unless diff.key?(:old)
          diff[:new] = [] unless diff.key?(:new)
          diff[:old].delete_if{|line| line == [' ', '']}
          diff[:new].delete_if{|line| line == [' ', '']}
          diff[:old], diff[:new] = add_blank_lines(diff[:old], diff[:new])
        end
      end
    end

    def compare_elements(old_element, new_element, indent_step = 0, path = '$')
      debug([
        'ENTER compare_elements',
        "Diffing #{path}"
      ])

      old_element_lines, new_element_lines = [], []

      if old_element == new_element
        debug('Equal elements, no diff required')

        old_element_lines = JSON.pretty_generate(old_element, max_nesting: false, quirks_mode: true).split("\n").map{|el| [' ', "#{indentation(indent_step)}#{el}"]}
        new_element_lines = JSON.pretty_generate(new_element, max_nesting: false, quirks_mode: true).split("\n").map{|el| [' ', "#{indentation(indent_step)}#{el}"]}
      else
        unless value_type(old_element) == value_type(new_element)
          debug('Opposite type element, no diff required')

          increment_diff_count(path, :insert)
          increment_diff_count(path, :delete)
          old_element_lines, new_element_lines = add_blank_lines(
            JSON.pretty_generate(old_element, max_nesting: false, quirks_mode: true).split("\n").map{|el| ['-', "#{indentation(indent_step)}#{el}"]},
            JSON.pretty_generate(new_element, max_nesting: false, quirks_mode: true).split("\n").map{|el| ['+', "#{indentation(indent_step)}#{el}"]}
          )
        else
          debug("Found #{value_type(old_element)}, diffing")

          increment_diff_count(path, :update)
          old_element_lines, new_element_lines = self.send("#{value_type(old_element)}_diff", old_element, new_element, indent_step, path)
        end
      end

      return old_element_lines, new_element_lines
    end

    def array_diff(old_array, new_array, indent_step, base_path)
      debug('ENTER array_diff')

      oal, nal   = old_array.length, new_array.length
      sal        = oal < nal ? oal : nal
      lal        = oal > nal ? oal : nal
      old_array_lines, new_array_lines = [[' ', "#{indentation(indent_step)}["]], [[' ', "#{indentation(indent_step)}["]]
      next_step = indent_step + 1
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
        debug("PROCESS INDEX #{i}")

        item_path = "#{base_path}[#{i}]"
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

        # Call compare_elements for sub-elements if necessary
        if (!(item_diff_operations & ['none', 'arr_change_value']).empty? and
          is_json_element?(old_array[i]) and is_json_element?(new_array[i])
        )
          old_item_lines, new_item_lines = compare_elements(old_array[i], new_array[i], next_step, item_path)
        else
          # Grab old and new items
          # UndefinedValue class is here to represent the difference between explicit null and non-existent
          old_item = item_diff_operations.include?('arr_add_index') ? UndefinedValue.new : old_array[i]
          new_item = item_diff_operations.include?('arr_drop_index') ? UndefinedValue.new : new_array[i]

          # Figure out operators for left and right
          if item_diff_operations.include?('none')
            old_operator, new_operator = ' '
          elsif item_diff_operations.include?('arr_change_value')
            increment_diff_count(item_path, :update)
            old_operator, new_operator = '-', '+'
          elsif (item_diff_operations & ['arr_send_move', 'arr_receive_move']).length == 2
            increment_diff_count(item_path, :move)
            old_operator, new_operator = 'M', 'M'
          elsif item_diff_operations.include?('arr_add_value')
            increment_diff_count(item_path, :insert)
            old_operator, new_operator = 'M', '+'
          elsif item_diff_operations.include?('arr_drop_value')
            increment_diff_count(item_path, :delete)
            old_operator, new_operator = '-', 'M'
          elsif item_diff_operations.include?('arr_drop_index')
            if item_diff_operations.include?('arr_send_move')
              increment_diff_count(item_path, :move)
              old_operator, new_operator = 'M', ' '
            else
              increment_diff_count(item_path, :delete)
              old_operator, new_operator = '-', ' '
            end
          elsif item_diff_operations.include?('arr_add_index')
            if item_diff_operations.include?('arr_receive_move')
              old_operator, new_operator = ' ', 'M'
            else
              increment_diff_count(item_path, :insert)
              old_operator, new_operator = ' ', '+'
            end
          end

          # Gather lines
          if old_item.is_a?(UndefinedValue)
            new_item_lines = JSON.pretty_generate(new_item, max_nesting: false, quirks_mode: true).split("\n").map{|il| [new_operator, "#{indentation(next_step)}#{il}"]}

            (0..(new_item_lines.length - 1)).each do |i|
              old_item_lines << [' ', '']
            end
          else
            old_item_lines = JSON.pretty_generate(old_item, max_nesting: false, quirks_mode: true).split("\n").map{|il| [old_operator, "#{indentation(next_step)}#{il}"]}
          end

          if new_item.is_a?(UndefinedValue)
            (0..(old_item_lines.length - 1)).each do |i|
              new_item_lines << [' ', '']
            end
          else
            new_item_lines = JSON.pretty_generate(new_item, max_nesting: false, quirks_mode: true).split("\n").map{|il| [new_operator, "#{indentation(next_step)}#{il}"]}
          end
        end

        unless old_item_lines.empty?
          old_item_lines.last[1] = "#{old_item_lines.last[1]}," if !last_loop and (old_item_lines.last[1].match(/[^\s]/))
        end
        unless new_item_lines.empty?
          new_item_lines.last[1] = "#{new_item_lines.last[1]}," if !last_loop and (new_item_lines.last[1].match(/[^\s]/))
        end

        old_item_lines, new_item_lines = add_blank_lines(old_item_lines, new_item_lines)

        add_object_sub_diff_if_required(item_path, old_item, old_item_lines) if old_item.is_a?(Hash) and old_operator == '-'
        add_object_sub_diff_if_required(item_path, new_item, new_item_lines, :new) if new_item.is_a?(Hash) and new_operator == '+'

        old_array_lines += old_item_lines
        new_array_lines += new_item_lines
      end

      old_array_lines << [' ', "#{indentation(indent_step)}]"]
      new_array_lines << [' ', "#{indentation(indent_step)}]"]

      return old_array_lines, new_array_lines
    end

    def object_diff(old_object, new_object, indent_step, base_path)
      debug('ENTER object_diff')

      keys = {
        'all'    => (old_object.keys | new_object.keys),
        'common' => (old_object.keys & new_object.keys),
        'add'    => (new_object.keys - old_object.keys),
        'drop'   => (old_object.keys - new_object.keys)
      }
      old_object_lines, new_object_lines = [[' ', "#{indentation(indent_step)}{"]], [[' ', "#{indentation(indent_step)}{"]]
      next_step = indent_step + 1

      # For objects, we're taking a much simpler approach, so no movements
      keys['all'].each do |k|
        debug("PROCESS KEY #{k}")

        item_path = "#{base_path}{#{k}}"
        key_string = "#{JSON.pretty_generate(k)}: "
        old_item_lines, new_item_lines = [], []
        last_loop = (k == keys['all'].last)

        if keys['common'].include?(k)
          if is_json_element?(old_object[k]) and is_json_element?(new_object[k]) and !@opts[:ignore_object_keys].include?(k)
            old_item_lines, new_item_lines = compare_elements(old_object[k], new_object[k], next_step, item_path)
          else
            if old_object[k] == new_object[k] or @opts[:ignore_object_keys].include?(k)
              old_item_lines = JSON.pretty_generate(old_object[k], max_nesting: false, quirks_mode: true).split("\n").map!{|il| [' ', "#{indentation(next_step)}#{il}"]}
              new_item_lines = JSON.pretty_generate(new_object[k], max_nesting: false, quirks_mode: true).split("\n").map!{|il| [' ', "#{indentation(next_step)}#{il}"]}
            else
              increment_diff_count(item_path, :update)
              old_item_lines = JSON.pretty_generate(old_object[k], max_nesting: false, quirks_mode: true).split("\n").map!{|il| ['-', "#{indentation(next_step)}#{il}"]}
              new_item_lines = JSON.pretty_generate(new_object[k], max_nesting: false, quirks_mode: true).split("\n").map!{|il| ['+', "#{indentation(next_step)}#{il}"]}
            end
          end
        else
          if keys['drop'].include?(k)
            increment_diff_count(item_path, :delete) unless @opts[:ignore_object_keys].include?(k)
            old_item_lines = JSON.pretty_generate(old_object[k], max_nesting: false, quirks_mode: true).split("\n").map!{|il| [@opts[:ignore_object_keys].include?(k) ? ' ' : '-', "#{indentation(next_step)}#{il}"]}
            new_item_lines = []

            (0..(old_item_lines.length - 1)).each do |i|
              new_item_lines << [' ', '']
            end
          elsif keys['add'].include?(k)
            increment_diff_count(item_path, :insert) unless @opts[:ignore_object_keys].include?(k)
            new_item_lines = JSON.pretty_generate(new_object[k], max_nesting: false, quirks_mode: true).split("\n").map!{|il| [@opts[:ignore_object_keys].include?(k) ? ' ' : '+', "#{indentation(next_step)}#{il}"]}
            old_item_lines = []

            (0..(new_item_lines.length - 1)).each do |i|
              old_item_lines << [' ', '']
            end
          end
        end

        unless old_item_lines.empty?
          old_item_lines[0][1].gsub!(/^(?<spaces>\s+)(?<content>.+)$/, "\\k<spaces>#{key_string}\\k<content>")
          old_item_lines.last[1] = "#{old_item_lines.last[1]}," if !last_loop and (old_item_lines.last[1].match(/[^\s]/))
        end
        unless new_item_lines.empty?
          new_item_lines[0][1].gsub!(/^(?<spaces>\s+)(?<content>.+)$/, "\\k<spaces>#{key_string}\\k<content>")
          new_item_lines.last[1] = "#{new_item_lines.last[1]}," if !last_loop and (new_item_lines.last[1].match(/[^\s]/))
        end

        old_item_lines, new_item_lines = add_blank_lines(old_item_lines, new_item_lines)

        old_object_lines += old_item_lines
        new_object_lines += new_item_lines
      end

      old_object_lines << [' ', "#{indentation(indent_step)}}"]
      new_object_lines << [' ', "#{indentation(indent_step)}}"]

      add_object_sub_diff_if_required(base_path, old_object, old_object_lines)
      add_object_sub_diff_if_required(base_path, new_object, new_object_lines, :new)

      return old_object_lines, new_object_lines
    end

    def debug(message)
      puts message if @opts[:debug]
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
      step = 0 if step < 0
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

    def increment_diff_count(path, operation)
      unless @filtered
        @diff[:count][operation] += 1
      else
        do_count = false

        # Any path prefixes in `only` that match?
        if (
          @opts[:diff_count_filter].key?(:only) and
          @opts[:diff_count_filter][:only].is_a?(Array) and
          !@opts[:diff_count_filter][:only].empty?
        )
          @opts[:diff_count_filter][:only].each do |only_path|
            unless ['none', 'lower'].include?(path_inclusion(path, only_path))
              do_count = true
              break
            else
              next
            end
          end
        else
          # If :only is empty or non-existent, count everything
          do_count = true
        end

        # Make sure the specific path is not excluded, if we've established that we should probably include it
        if (
          do_count and
          @opts[:diff_count_filter].key?(:except) and
          @opts[:diff_count_filter][:except].is_a?(Array) and
          !@opts[:diff_count_filter][:except].empty?
        )
          @opts[:diff_count_filter][:except].each do |except_path|
            unless ['none', 'lower'].include?(path_inclusion(path, except_path))
              do_count = false
              break
            else
              next
            end
          end
        end

        # Ensure this operation is allowed for counting
        if (
          do_count and
          @opts[:diff_count_filter].key?(:operations) and
          @opts[:diff_count_filter][:operations].is_a?(Array)
        )
          do_count = false if (
            !@opts[:diff_count_filter][:operations].empty? and
            !@opts[:diff_count_filter][:operations].include?(operation)
          )
        end

        @diff[:count][:all]      += 1 if do_count
        @diff[:count][operation] += 1 if do_count
      end
    end

    def path_inclusion(current_path, check_path)
      check_path_prefix = check_path.gsub(/\*/, '')
      check_path_wildcard = check_path.gsub(/[^\*]/, '') || ''

      if current_path.include?(check_path_prefix)
        current_path_remainder = current_path.gsub(check_path_prefix, '').split(/(\]\[|\]\{|\}\[|\}\{)/)

        return 'exact' if (current_path_remainder.length == 0 and check_path_wildcard.length == 0)
        return 'level' if (current_path_remainder.length == 1 and check_path_wildcard == '*')
        return 'full'  if (current_path_remainder.length > 0 and check_path_wildcard == '**')
        return 'lower' if (current_path_remainder.length > 0)
      else
        return 'none'
      end
    end

    def add_object_sub_diff_if_required(object_path, object, lines, side = :old)
      if (
        @opts.key?(:generate_object_sub_diffs) and
        @opts[:generate_object_sub_diffs].is_a?(Hash) and
        !@opts[:generate_object_sub_diffs].empty?
      )
        @opts[:generate_object_sub_diffs].each do |k,v|
          unless ['none', 'lower'].include?(path_inclusion(object_path, k))
            @diff[:sub_diffs][v] = {} unless @diff[:sub_diffs].key?(v)
            @diff[:sub_diffs][v][object[v]] = {} unless @diff[:sub_diffs][v].key?(object[v])
            @diff[:sub_diffs][v][object[v]][side] = lines if object.key?(v)
          end
        end
      end
    end
  end
end
