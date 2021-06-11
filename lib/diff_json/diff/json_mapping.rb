module JsonMapping
  private

  def path_indentation(path)
    return 0 if path.empty?
    return path.sub('/', '').split('/').length
  end

  def sortable_path(path)
    return [''] if path.empty?
    return path.split('/').map{|p| (p =~ /^\d+$/).nil? ? p : p.to_i}
  end

  def gather_paths(old_paths, new_paths, sort = false)
    gathered_paths = []

    if sort
      sortable_paths = (old_paths | new_paths).map{|path| sortable_path(path)}

      sortable_paths.sort! do |x,y|
        last_index = x.length > y.length ? (x.length - 1) : (y.length - 1)
        sort_value = nil

        (0..last_index).each do |i|
          next if x[i] == y[i]

          sort_value = case [x[i].class.name, y[i].class.name]
          when ['NilClass', 'Fixnum'], ['NilClass', 'Integer'], ['NilClass', 'String'], ['Fixnum', 'String'], ['Integer', 'String']
            -1
          when ['Fixnum', 'NilClass'], ['Integer', 'NilClass'], ['String', 'NilClass'], ['String', 'Fixnum'], ['String', 'Integer']
            1
          else
            x[i] <=> y[i]
          end

          break unless sort_value.nil?
        end

        sort_value
      end

      return sortable_paths.map{|path| path.join('/')}
    else
      ### Implementation in progress, for now, raise error
      raise 'Natural sort order is WIP, for now, do not override the :path_sort option'
    end

    return gathered_paths
  end

  def is_structure?(value)
    return (value.is_a?(Array) or value.is_a?(Hash))
  end

  def element_metadata(path, value, **overrides)
    hash_list    = (value.is_a?(Array) ? value.map{|x| x.hash} : [])
    is_structure = is_structure?(value)
    array_type   = nil

    if is_structure and value.is_a?(Array)
      structure_detection = value.map{|v| is_structure?(v)}.uniq

      array_type = if structure_detection.empty?
        :empty
      elsif structure_detection.length > 1
        :mixed
      else
        (structure_detection.first ? :structures : :primitives)
      end
    end

    return {
      :hash_list      => hash_list,
      :indentation    => path_indentation(path),
      :index          => 0,
      :key            => nil,
      :length         => (is_structure ? value.length : nil),
      :trailing_comma => false,
      :type           => (is_structure ? value.class.name.downcase.to_sym : :primitive),
      :array_type     => array_type,
      :value          => value
    }.merge(overrides)
  end

  def map_json(json, base_path, index, parent_length = 1, **metadata_overrides)
    map            = {}
    map[base_path] = element_metadata(base_path, json, index: index, trailing_comma: (index < (parent_length - 1)), **metadata_overrides)

    if json.is_a?(Array)
      json.each_with_index do |value, i|
        index_path = "#{base_path}/#{i}"

        if value.is_a?(Array)
          map.merge!(map_json(value, index_path, i, value.length))
        elsif value.is_a?(Hash)
          map.merge!(map_json(value, index_path, i, value.keys.length))
        else
          map[index_path] = element_metadata(index_path, value, index: i, trailing_comma: (i < (json.length - 1)))
        end
      end
    elsif json.is_a?(Hash)
      json      = (@opts[:path_sort] == :sorted ? json.to_a.sort.to_h : json)
      key_index = 0

      json.each do |key, value|
        key_path = "#{base_path}/#{key}"

        if value.is_a?(Array)
          map.merge!(map_json(value, key_path, key_index, value.length, key: key))
        elsif value.is_a?(Hash)
          map.merge!(map_json(value, key_path, key_index, value.keys.length, key: key))
        else
          map[key_path] = element_metadata(key_path, value, index: key_index, trailing_comma: (key_index < (json.keys.length - 1)), key: key)
        end

        key_index = key_index.next
      end
    end

    return map
  end
end
