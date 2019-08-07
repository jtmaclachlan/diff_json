module DiffJson
  class HtmlOutput
    def initialize(diff, **opts)
      @diff = diff
      @opts = {
        table_id_prefix: 'diff_json_view_0',
        markup_type: :bootstrap
      }
      @markup = build
    end

    def markup
      return @markup
    end

    def diff
      return @diff
    end

    private

    def build
      new_markup = {main: table_markup(@diff, @opts[:table_id_prefix]), sub_diffs: {}}

      @diff.sub_diffs.each do |sdid, sub_diff|
        new_markup[:sub_diffs][sdid] = table_markup(sub_diff, sdid)
      end

      return new_markup
    end

    def table_markup(table_diff, table_id_prefix)
      markup_lines = {left: "", right: "", full: "", sub_diffs: {}}

      html_opener = self.method("html_#{@opts[:markup_type]}_opener".to_sym).call(table_id_prefix)
      markup_lines[:left]  = html_opener[:left]
      markup_lines[:right] = html_opener[:right]
      markup_lines[:full]  = html_opener[:full]

      hierarchy_lock = nil
      structure_queue = []

      table_diff.paths.each_with_index do |path, i|
        skip_path = (!hierarchy_lock.nil? and !(path =~ /^#{hierarchy_lock}.+$/).nil?)
        unless skip_path
          if !hierarchy_lock.nil?
            hierarchy_lock = nil
          end

          old_element, new_element = table_diff.json_map(:old)[path], table_diff.json_map(:new)[path]

          operations = (table_diff.diff[path] || []).map{|op|
            case op[:op]
            when :ignore, :add, :replace, :remove
              op[:op]
            when :move
              op[:from] == path ? :send_move : :receive_move
            end
          }.compact

          if operations.empty? or operations.include?(:ignore)
            left_operators = '  '
            right_operators = '  '
          else
            left_operators = [operations.include?(:send_move) ? 'M' : ' ', (operations & [:replace, :remove]).length > 0 ? '-' : ' '].join
            right_operators = [operations.include?(:receive_move) ? 'M' : ' ', (operations & [:add, :replace]).length > 0 ? '+' : ' '].join
          end

          if !old_element.nil? and !new_element.nil?
            if (old_element[:value] == new_element[:value]) or (operations & [:ignore, :replace]).length > 0
              old_lines, new_lines = balance_output(old_element[:value], new_element[:value], indentation: old_element[:indentation], old_key: old_element[:key], new_key: new_element[:key], old_comma: old_element[:trailing_comma], new_comma: new_element[:trailing_comma])
              hierarchy_lock = path unless old_element[:type] == :primitive and new_element[:type] == :primitive
            else
              old_lines = jpg(nil, structure: true, structure_position: :open, structure_type: old_element[:type], indentation: old_element[:indentation], key: old_element[:key], trailing_comma: false)
              new_lines = jpg(nil, structure: true, structure_position: :open, structure_type: new_element[:type], indentation: new_element[:indentation], key: new_element[:key], trailing_comma: false)
              structure_queue.push({path: path, type: old_element[:type], indentation: old_element[:indentation], old_comma: old_element[:trailing_comma], new_comma: new_element[:trailing_comma]})
            end
          elsif old_element.nil?
            old_lines, new_lines = balance_output(UndefinedValue.new, new_element[:value], indentation: new_element[:indentation], new_key: new_element[:key], new_comma: new_element[:trailing_comma])
            hierarchy_lock = path unless new_element[:type] == :primitive
          else
            old_lines, new_lines = balance_output(old_element[:value], UndefinedValue.new, indentation: old_element[:indentation], old_key: old_element[:key], old_comma: old_element[:trailing_comma])
            hierarchy_lock = path unless old_element[:type] == :primitive
          end

          compiled_lines = self.method("html_#{@opts[:markup_type]}_lines".to_sym).call(left_operators, old_lines, right_operators, new_lines)
          markup_lines[:left] << compiled_lines[:left]
          markup_lines[:right] << compiled_lines[:right]
          markup_lines[:full] << compiled_lines[:full]
        end

        unless structure_queue.empty?
          if i == (table_diff.paths.length - 1)
            structure_queue.reverse.each do |sq|
              old_lines = jpg(nil, structure: true, structure_position: :close, structure_type: sq[:type], indentation: sq[:indentation], trailing_comma: sq[:old_comma])
              new_lines = jpg(nil, structure: true, structure_position: :close, structure_type: sq[:type], indentation: sq[:indentation], trailing_comma: sq[:new_comma])
              compiled_lines = self.method("html_#{@opts[:markup_type]}_lines".to_sym).call('  ', old_lines, '  ', new_lines)
              markup_lines[:left] << compiled_lines[:left]
              markup_lines[:right] << compiled_lines[:right]
              markup_lines[:full] << compiled_lines[:full]
            end
          else
            if (table_diff.paths[(i+1)] =~ /^#{structure_queue.last[:path]}.+$/).nil?
              sq = structure_queue.pop
              old_lines = jpg(nil, structure: true, structure_position: :close, structure_type: sq[:type], indentation: sq[:indentation], trailing_comma: sq[:old_comma])
              new_lines = jpg(nil, structure: true, structure_position: :close, structure_type: sq[:type], indentation: sq[:indentation], trailing_comma: sq[:new_comma])
              compiled_lines = self.method("html_#{@opts[:markup_type]}_lines".to_sym).call('  ', old_lines, '  ', new_lines)
              markup_lines[:left] << compiled_lines[:left]
              markup_lines[:right] << compiled_lines[:right]
              markup_lines[:full] << compiled_lines[:full]
            end
          end
        end
      end

      html_closer = self.method("html_#{@opts[:markup_type]}_closer".to_sym).call
      markup_lines[:left] << html_closer[:left]
      markup_lines[:right] << html_closer[:right]
      markup_lines[:full] << html_closer[:full]

      return markup_lines
    end

    def html_table_opener(table_id_prefix)
      compiled_lines = {}
      compiled_lines[:left]  = "<table id=\"#{table_id_prefix}_left\" class=\"diff-json-view diff-json-split-view-left\">\n"
      compiled_lines[:right] = "<table id=\"#{table_id_prefix}_right\" class=\"diff-json-view diff-json-split-view-right\">\n"
      compiled_lines[:full]  = "<table id=\"#{table_id_prefix}_full\" class=\"diff-json-view diff-json-full-view\">\n"

      return compiled_lines
    end

    def html_table_lines(left_operators, left_lines, right_operators, right_lines)
      compiled_lines = {left: "", right: "", full: ""}

      (0..(left_lines.length - 1)).each do |i|
        compiled_lines[:left] << <<-EOL
          <tr class="diff-json-view-line">
            <td class="diff-json-view-line-operator"><pre>#{left_operators unless left_lines[i].empty?}</pre></td>
            <td class="diff-json-view-line-content"><pre class="diff-json-line-breaker">#{left_lines[i]}</pre></td>
          </tr>
        EOL
        compiled_lines[:right] << <<-EOL
        <tr class="diff-json-view-line">
          <td class="diff-json-view-line-operator"><pre>#{right_operators unless right_lines[i].empty?}</pre></td>
          <td class="diff-json-view-line-content"><pre class="diff-json-line-breaker">#{right_lines[i]}</pre></td>
        </tr>
        EOL
        compiled_lines[:full] << <<-EOL
        <tr class="diff-json-view-line">
          <div class="row">
            <td class="diff-json-view-line-operator"><pre>#{left_operators unless left_lines[i].empty?}</pre></td>
            <td class="diff-json-view-line-content"><pre class="diff-json-line-breaker">#{left_lines[i]}</pre></td>
            <td class="diff-json-view-column-break"></td>
            <td class="diff-json-view-line-operator"><pre>#{right_operators unless right_lines[i].empty?}</pre></td>
            <td class="diff-json-view-line-content"><pre class="diff-json-line-breaker">#{right_lines[i]}</pre></td>
          </div>
        </tr>
        EOL
      end

      return compiled_lines
    end

    def html_table_closer
      compiled_lines = {}
      compiled_lines[:left] = "</table>"
      compiled_lines[:right] = "</table>"
      compiled_lines[:full] = "</table>"

      return compiled_lines
    end

    def html_bootstrap_opener(table_id_prefix)
      compiled_lines = {}
      compiled_lines[:left]  = "<div id=\"#{table_id_prefix}_left\" class=\"diff-json-view diff-json-split-view-left col-xs-6 col-6\">\n"
      compiled_lines[:right] = "<div id=\"#{table_id_prefix}_right\" class=\"diff-json-view diff-json-split-view-right col-xs-6 col-6\">\n"
      compiled_lines[:full]  = "<div id=\"#{table_id_prefix}_full\" class=\"diff-json-view diff-json-full-view col-xs-12 col-12\">\n"

      return compiled_lines
    end

    def html_bootstrap_lines(left_operators, left_lines, right_operators, right_lines)
      compiled_lines = {left: "", right: "", full: ""}

      (0..(left_lines.length - 1)).each do |i|
        compiled_lines[:left] << <<-EOL
          <div class="diff-json-view-line row">
            <div class="diff-json-view-line-operator col-1"><pre>#{left_operators unless left_lines[i].empty?}</pre></div>
            <div class="diff-json-view-line-content col-11"><pre class="diff-json-line-breaker">#{left_lines[i]}</pre></div>
          </div>
        EOL
        compiled_lines[:right] << <<-EOL
        <div class="diff-json-view-line row">
          <div class="diff-json-view-line-operator col-1"><pre>#{right_operators unless right_lines[i].empty?}</pre></div>
          <div class="diff-json-view-line-content col-11"><pre class="diff-json-line-breaker">#{right_lines[i]}</pre></div>
        </div>
        EOL
        compiled_lines[:full] << <<-EOL
        <div class="diff-json-view-line row">
          <div class="diff-json-view-line-left col-6">
            <pre class="diff-json-line-breaker">#{left_operators unless left_lines[i].empty?} #{left_lines[i]}</pre>
          </div>
          <div class="diff-json-view-line-right col-6">
            <pre class="diff-json-line-breaker">#{right_operators unless right_lines[i].empty?} #{right_lines[i]}</pre>
          </div>
        </div>
        EOL
      end

      return compiled_lines
    end

    def html_bootstrap_closer
      compiled_lines = {}
      compiled_lines[:left] = "</div>"
      compiled_lines[:right] = "</div>"
      compiled_lines[:full] = "</div>"

      return compiled_lines
    end

    def balance_output(old_element, new_element, indentation: 0, old_key: nil, new_key: nil, old_comma: false, new_comma: false)
      old_lines, new_lines = jpg(old_element, indentation: indentation, key: old_key, trailing_comma: old_comma), jpg(new_element, indentation: indentation, key: new_key, trailing_comma: new_comma)
      return old_lines, new_lines if old_lines.length == new_lines.length

      if old_lines.length > new_lines.length
        (old_lines.length - new_lines.length).times do
          new_lines << ''
        end
      else
        (new_lines.length - old_lines.length).times do
          old_lines << ''
        end
      end

      return old_lines, new_lines
    end

    def jpg(json_element, structure: false, structure_position: :open, structure_type: :array, indentation: 0, key: nil, trailing_comma: false)
      return [] if json_element.is_a?(DiffJson::UndefinedValue)
      if structure
        generated_element = case [structure_position, structure_type]
        when [:open, :array]
          ['[']
        when [:close, :array]
          [']']
        when [:open, :hash]
          ['{']
        when [:close, :hash]
          ['}']
        end
      else
        generated_element = JSON.pretty_generate(json_element, max_nesting: false, quirks_mode: true).lines
      end
      generated_element[0].prepend("#{key}: ") unless key.nil?
      generated_element.last << ',' if trailing_comma
      return generated_element.map{|line| line.prepend('  ' * indentation)}
    end
  end
end
