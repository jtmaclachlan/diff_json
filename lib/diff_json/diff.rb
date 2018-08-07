module DiffJson
  class Diff
    def initialize(old_json, new_json, **opts)
      @old_json = old_json
      @new_json = new_json
      # Set base options and merge user specified kwargs
      @opts = {
        :skip_diff_highlight_keys  => [],
        :skip_diff_highlight_paths => []
      }.merge(opts)
      # Diff info container
      @diff = {}
      @diff_ct = 0
    end

    def calculate
      @diff = compare_elements(@old_json, @new_json)
    end

    def retrieve_output(output_type = :stdout)
      case output_type
      when :raw
        return JSON.pretty_generate(@diff)
      when :stdout
      when :file
      when :html
      end
    end

    private

    def compare_elements(old_element, new_element, path = '$')
      element_diff = {
        'diff_json_element'   => true,
        'diff_json_operation' => nil,
        'diff_json_types'     => {
          'old' => value_type(old_element),
          'new' => value_type(new_element)
        }
      }

      if old_element == new_element
        element_diff['diff_json_operation'] = 'none'
        element_diff['diff_json_value']     = old_element
      else
        unless element_diff['diff_json_types']['old'] == element_diff['diff_json_types']['new']
          element_diff['diff_json_operation'] = 'replace'
          element_diff['diff_json_values']    = {
            'old' => old_element,
            'new' => new_element
          }
        else
          element_diff['diff_json_operation'] = 'update'
          element_diff.merge!(self.send("#{element_diff['diff_json_types']['old']}_diff", old_element, new_element, path))
        end
      end

      return element_diff
    end

    def array_diff(old_array, new_array, base_path)
      oal, nal   = old_array.length, new_array.length
      sal        = oal < nal ? oal : nal
      lal        = oal > nal ? oal : nal
      diff       = {}
      operations = {
        'none'             => [],
        'arr_add_index'    => [],
        'arr_drop_index'   => [],
        'arr_change_value' => [],
        'arr_add_value'    => [],
        'arr_drop_value'   => [],
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
        index_path = "#{base_path}[#{i}]"

        if operations['none'].include?(i)
          diff[i] = {
            'diff_json_operation' => 'none',
            'diff_json_type'      => value_type(old_array[i]),
            'diff_json_value'     => old_array[i]
          }
        else
          diff[i] = {
            'diff_json_operations' => [],
            'diff_json_types' => {
              'old' => value_type(old_array[i]),
              'new' => value_type(new_array[i])
            },
            'diff_json_values' => {
              'old' => old_array[i],
              'new' => new_array[i]
            }
          }

          # Assign current known operations to each index
          (operations.keys - ['none']).each do |operation|
            if operations[operation].include?(i)
              diff[i]['diff_json_operations'] << operation
            end
          end

          # Assign local change operations and find diff for subelements
          if diff[i]['diff_json_operations'].empty?
            if is_json_element?(old_array[i]) and is_json_element?(new_array[i])
              diff[i] = compare_elements(old_array, new_array, index_path)
            else
              diff[i]['diff_json_operations'] << 'change_value'
            end
          elsif (
            diff[i]['diff_json_operations'].include?('arr_send_move') and
            !diff[i]['diff_json_operations'].include?('arr_receive_move') and
            !diff[i]['diff_json_operations'].include?('arr_drop_index')
          )
            diff[i]['diff_json_operations'] << 'arr_add_value'
          elsif (
            !diff[i]['diff_json_operations'].include?('arr_send_move') and
            diff[i]['diff_json_operations'].include?('arr_receive_move') and
            !diff[i]['diff_json_operations'].include?('arr_add_index')
          )
            diff[i]['diff_json_operations'] << 'arr_drop_value'
          end
        end

      end

      return diff
    end

    def object_diff(old_object, new_object, base_path)
      keys = {
        'all'    => (old_object.keys | new_object.keys),
        'common' => (old_object.keys & new_object.keys),
        'add'    => (new_object.keys - old_object.keys),
        'drop'   => (old_object.keys - new_object.keys)
      }
      diff = {}

      # For objects, we're taking a much simpler approach, so no movements
      keys['all'].each do |k|
        key_path = "#{base_path}{#{k}}"
        diff[k] = {}

        if keys['common'].include?(k)
          if old_object[k] == new_object[k]
            diff[k] = {
              'diff_json_operation' => 'none',
              'diff_json_type'      => value_type(old_object[k]),
              'diff_json_value'     => old_object[k]
            }
          else
            if is_json_element?(old_object[k]) and is_json_element?(new_object[k])
              diff[k] = compare_elements(old_object[k], new_object[k], key_path)
            else
              diff[k] = {
                'diff_json_operation' => 'obj_change_value',
                'diff_json_types' => {
                  'old' => value_type(old_object[k]),
                  'new' => value_type(new_object[k])
                },
                'diff_json_values' => {
                  'old' => old_object[k],
                  'new' => new_object[k]
                }
              }
            end
          end
        else
          if keys['add'].include?(k)
            key_operation = 'add_key'
            key_type      = value_type(new_object[k])
            key_value     = new_object[k]
          else
            key_operation = 'drop_key'
            key_type      = value_type(old_object[k])
            key_value     = old_object[k]
          end

          diff[k] = {
            'diff_json_operation' => key_operation,
            'diff_json_type'      => key_type,
            'diff_json_value'     => key_value
          }
        end

        diff[k]['diff_json_ignore'] = true if @opts[:skip_diff_highlight_keys].include?(k)
      end

      return diff
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
  end
end
