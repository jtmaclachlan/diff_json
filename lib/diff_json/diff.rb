require_rel './diff'

module DiffJson
  def self.diff(old_json, new_json, return_type, diff_opts = {}, output_opts = {})
    completed_diff = Diff.new(old_json, new_json, **diff_opts)

    return case return_type
    when :raw
      completed_diff
    when :patch
      patch_operations = []

      completed_diff.diff.each do |path, operations|
        operations.each do |op|
          patch_operations << op if [:add, :replace, :remove].include?(op[:op]) or (op[:op] == :move and path == op[:from])
        end
      end

      return patch_operations
    when :html
      HtmlOutput.new(completed_diff, **output_opts)
    end
  end

  class Diff
    include JsonMapping
    include JsonDiffing

    def initialize(old_json, new_json, **opts)
      # Set config options
      @opts = {
        count_operations: {
          '/**' => [:add, :replace, :remove, :move, :update]
        },
        ignore_paths: [],
        path_sort: :sorted,
        sub_diffs: {},
        track_array_moves: true,
        track_structure_updates: false,
        replace_primitives_arrays: false,
        logger: ::Logger.new(STDOUT),
        log_level: :warn
      }.merge(opts)
      # Create map of both JSON objects
      @old_map = map_json(old_json, '', 0)
      @new_map = map_json(new_json, '', 0)
      # Gather the full list of all paths in both JSON objects in a consistent order
      @all_paths = gather_paths(@old_map.keys, @new_map.keys, @opts[:path_sort] == :sorted)
      # Generate diff operations list
      @diff = diff_check(old_json, new_json)
      # Find difference counts
      @counts = find_counts(@diff)
      # Gather sub-diffs
      @sub_diffs = generate_sub_diffs
    end

    def count(count_type = :all)
      return case count_type
      when :ignore, :add, :replace, :remove, :move, :update
        @counts[count_type] || 0
      when :total
        @counts.values.sum
      else
        @counts
      end
    end

    def diff
      return @diff
    end

    def json_map(version = :old)
      return (version == :old ? @old_map : @new_map)
    end

    def paths(version = :joint)
      return case version
      when :old
        json_map(:old).keys
      when :new
        json_map(:new).keys
      else
        @all_paths
      end
    end

    def sub_diffs
      return @sub_diffs
    end

    def log_message(log_level, message)
      log_levels = [
        :debug,
        :info,
        :warn,
        :error
      ]

      if (log_levels.index(log_level) || -1) >= (log_levels.index(@opts[:log_level]) || 0)
        @opts[:logger].method(log_level).call((is_structure?(message) ? JSON.pretty_generate(message) : message))
      end
    end
  end
end
