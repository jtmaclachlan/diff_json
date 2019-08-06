module DiffJson
  class HtmlOutput

    def initialize(diff, **opts)
      @diff = diff
      @opts = {
        :table_id_prefix => 'diff_json_view_0'
      }.merge(opts)
      @output = {
        :full_diff => {},
        :sub_diffs => {}
      }

      calculate
    end

    def full
      return @output[:full_diff][:full]
    end

    def left
      return @output[:full_diff][:left]
    end

    def right
      return @output[:full_diff][:right]
    end

    def sub_diffs
      return @output[:sub_diffs]
    end

    private

    def calculate
      @output[:full_diff] = table_markup(@opts[:table_id_prefix], @diff.diff)

      @diff.sub_diffs.each do |key, sub_diffs|
        sub_diffs.each do |value, diff|
          sub_key = "#{key}::#{value}"
          table_key = "#{key}_#{value}"
          @output[:sub_diffs][sub_key] = table_markup("#{@opts[:table_id_prefix]}_sub_diff_#{table_key}", diff)
        end
      end
    end

    def table_markup(table_id_prefix, lines)
      markup = {
        :full  => "",
        :left  => "",
        :right => ""
      }

      markup[:full]  = "<table id=\"#{table_id_prefix}_full\" class=\"diff-json-view diff-json-full-view\">\n"
      markup[:left]  = "<table id=\"#{table_id_prefix}_left\" class=\"diff-json-view diff-json-split-view-left\">\n"
      markup[:right] = "<table id=\"#{table_id_prefix}_right\" class=\"diff-json-view diff-json-split-view-right\">\n"

      (0..(lines[:old].length - 1)).each do |i|
        # Full, combined table output
        markup[:full]  += "  <tr class=\"diff-json-view-line\">\n"
        markup[:full]  += "    <td class=\"diff-json-view-line-operator\"><pre>#{lines[:old][i][0]}</pre></td>\n"
        markup[:full]  += "    <td class=\"diff-json-view-line-content #{content_highlight_class(:left, lines[:old][i][0])}\"><pre>#{lines[:old][i][1]}</pre></td>\n"
        markup[:full]  += "    <td class=\"diff-json-view-column-break\"></td>\n"
        markup[:full]  += "    <td class=\"diff-json-view-line-operator\"><pre>#{lines[:new][i][0]}</pre></td>\n"
        markup[:full]  += "    <td class=\"diff-json-view-line-content #{content_highlight_class(:right, lines[:new][i][0])}\"><pre>#{lines[:new][i][1]}</pre></td>\n"
        markup[:full]  += "  </tr>\n"
        # Split, left side output
        markup[:left]  += "  <tr class=\"diff-json-view-line\">\n"
        markup[:left]  += "    <td class=\"diff-json-view-line-operator\"><pre>#{lines[:old][i][0]}</pre></td>\n"
        markup[:left]  += "    <td class=\"diff-json-view-line-content #{content_highlight_class(:left, lines[:old][i][0])}\"><pre>#{lines[:old][i][1]}</pre></td>\n"
        markup[:left]  += "  </tr>\n"
        # Split, right side output
        markup[:right] += "  <tr class=\"diff-json-view-line\">\n"
        markup[:right] += "    <td class=\"diff-json-view-line-operator\"><pre>#{lines[:new][i][0]}</pre></td>\n"
        markup[:right] += "    <td class=\"diff-json-view-line-content #{content_highlight_class(:right, lines[:new][i][0])}\"><pre>#{lines[:new][i][1]}</pre></td>\n"
        markup[:right] += "  </tr>\n"
      end

      markup[:full]  += "</table>\n"
      markup[:left]  += "</table>\n"
      markup[:right] += "</table>\n"

      return markup
    end

    def content_highlight_class(side, operator)
      if operator == '-'
        return 'diff-json-content-del'
      elsif operator == '+'
        return 'diff-json-content-ins'
      elsif operator == 'M'
        return side == :left ? 'diff-json-content-del' : 'diff-json-content-ins'
      else
        return ''
      end
    end
  end
end
