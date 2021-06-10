module JsonDiffing
  private

  def diff_check(old_element, new_element, base_path = '')
    diff_operations = {}

    if (old_element.is_a?(Array) and new_element.is_a?(Array)) or (old_element.is_a?(Hash) and new_element.is_a?(Hash))
      element_operations = case old_element.class.name
      when 'Array'
        diff_array(old_element, new_element, base_path)
      when 'Hash'
        diff_hash(old_element, new_element, base_path)
      end

      if @opts[:track_structure_updates]
        element_operations[base_path] = [{op: :update}] if element_operations.select{|k,v| count_path?(k, "#{base_path}/*")}.length > 0
      end

      diff_operations.merge!(element_operations)
    else
      diff_operations[base_path] = [{op: :replace, path: base_path, from: old_element, value: new_element}] unless old_element == new_element
    end

    return diff_operations
  end

  def diff_array(old_array, new_array, base_path)
    return {} if old_array == new_array

    diff_operations = {}
    add_drop_operations = {}
    last_shared_index = (old_array.length - 1)

    if @opts[:replace_primitives_arrays]
      if @old_map[base_path][:array_type] == :primitives and @new_map[base_path][:array_type] == :primitives
        diff_operations[base_path] = [{op: :replace, path: base_path, from: old_array, value: new_array}]
        return diff_operations
      end
    end

    if @opts[:track_array_moves]
      old_array_map   = old_array.each_with_index.map{|v,i| [i, v]}
      new_array_map   = new_array.each_with_index.map{|v,i| [i, v]}
      shared_elements = (old_array_map & new_array_map)
      old_move_check  = (old_array_map - shared_elements)
      new_move_check  = (new_array_map - shared_elements)
      possible_moves  = []
      max_moves       = (old_move_check.length < new_move_check.length ? old_move_check.length : new_move_check.length)

      if max_moves > 0
        old_move_check.each do |omc|
          destinations = new_move_check.map{|v| omc[1] == v[1] ? [(omc[0] - v[0]).abs, omc[0], v[0]] : nil}.compact.sort_by{|x| x[0]}
          if !destinations.empty? and possible_moves.length < max_moves
            possible_moves << {op: :move, from: "#{base_path}/#{destinations.first[1]}", path: "#{base_path}/#{destinations.first[2]}"}
          end
        end
      end
    end

    if new_array.length > old_array.length
      new_array[(old_array.length)..(new_array.length - 1)].each_with_index do |value, i|
        element_path = "#{base_path}/#{(old_array.length + i)}"
        add_drop_operations[element_path] = [{op: :add, path: element_path, value: value}]

        if @opts[:track_array_moves]
          element_move_search = possible_moves.select{|x| x[:path] == element_path}
          add_drop_operations[element_path] += element_move_search
        end
      end
    elsif old_array.length > new_array.length
      last_shared_index = new_array.length - 1

      old_array[(new_array.length)..(old_array.length - 1)].each_with_index do |value, i|
        element_index = (new_array.length + i)
        element_path = "#{base_path}/#{element_index}"
        add_drop_operations[element_path] = [{op: :remove, path: element_path, value: old_array[element_index]}]

        if @opts[:track_array_moves]
          element_move_search = possible_moves.select{|x| x[:from] == element_path}
          add_drop_operations[element_path] += element_move_search
        end
      end
    end

    (0..last_shared_index).each do |i|
      index_path = "#{base_path}/#{i}"

      if @opts[:track_array_moves]
        element_move_search = possible_moves.select{|x| x[:from] == index_path or x[:path] == index_path}
        element_move_search << {op: :replace, path: index_path, value: new_array[i]} if element_move_search.length == 1
        diff_operations.merge!(element_move_search.empty? ? diff_check(old_array[i], new_array[i], index_path) : {index_path => element_move_search})
      else
        unless @opts[:ignore_paths].include?(index_path)
          diff_operations.merge!(diff_check(old_array[i], new_array[i], index_path))
        else
          diff_operations[index_path] = [{op: :ignore}]
        end
      end
    end

    diff_operations.merge!(add_drop_operations)

    return diff_operations
  end

  def diff_hash(old_hash, new_hash, base_path)
    return {} if old_hash == new_hash

    diff_operations = {}
    old_keys, new_keys = old_hash.keys, new_hash.keys
    common_keys, added_keys, dropped_keys = (old_keys & new_keys), (new_keys - old_keys), (old_keys - new_keys)

    common_keys.each do |ck|
      element_path = "#{base_path}/#{ck}"

      unless @opts[:ignore_paths].include?(element_path)
        diff_operations.merge!(diff_check(old_hash[ck], new_hash[ck], element_path))
      else
        diff_operations[element_path] = [{op: :ignore}]
      end
    end

    added_keys.each do |ak|
      element_path = "#{base_path}/#{ak}"
      diff_operations[element_path] = [{op: :add, path: element_path, value: new_hash[ak]}]
    end

    dropped_keys.each do |dk|
      element_path = "#{base_path}/#{dk}"
      diff_operations[element_path] = [{op: :remove, path: element_path}]
    end

    return diff_operations
  end

  def generate_sub_diffs
    sub_diffs = {}

    @opts[:sub_diffs].each do |k,v|
      sub_diff_paths = @all_paths.select{|x| count_path?(x, k)}
      old_elements = @old_map.select{|k,v| sub_diff_paths.include?(k)}.values.map{|x| {x[:value][v[:key]] => x[:value]}}.reduce(:merge)
      new_elements = @new_map.select{|k,v| sub_diff_paths.include?(k)}.values.map{|x| {x[:value][v[:key]] => x[:value]}}.reduce(:merge)

      (old_elements.keys + new_elements.keys).uniq.each do |sub_diff_id|
        sub_diffs["#{k}::#{sub_diff_id}"] = DiffJson::Diff.new((old_elements[sub_diff_id] || {}), (new_elements[sub_diff_id] || {}), **v[:opts]) unless old_elements[sub_diff_id] == new_elements[sub_diff_id]
      end
    end

    return sub_diffs
  end

  def find_counts(diff_structure)
    counts = {
      ignore: 0,
      add: 0,
      replace: 0,
      remove: 0
    }
    counts[:move]   = 0 if @opts[:track_array_moves]
    counts[:update] = 0 if @opts[:track_structure_updates]

    diff_structure.each do |path, operations|
      inclusion = path_inclusion(path)

      operations.each do |op|
        counts[op[:op]] += 1 if (inclusion.include?(op[:op]) and ([:ignore, :add, :replace, :remove, :update].include?(op[:op]) or (op[:op] == :move and path == op[:from])))
      end
    end

    return counts
  end

  def path_inclusion(path)
    if @opts[:count_operations].include?('**')
      return @opts[:count_operations]['**']
    else
      @opts[:count_operations].each do |path_set, operations|
        return operations if count_path?(path, path_set)
      end

      return []
    end
  end

  def count_path?(path, inclusion)
    inclusion_base     = inclusion.gsub(/\/?\**$/, '')
    inclusion_wildcard = /\**$/.match(inclusion)[0]

    if path.include?(inclusion_base)
      trailing_elements = path.gsub(/^#{inclusion_base}\/?/, '').split('/').length

      return true if (
        (trailing_elements == 0 and inclusion_wildcard == '') or
        (trailing_elements == 1 and inclusion_wildcard == '*') or
        (trailing_elements > 0 and inclusion_wildcard == '**')
      )
    end

    return false
  end
end
