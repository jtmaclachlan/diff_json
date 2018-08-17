module DiffJson
  class HtmlOutput

    def initialize(diff, **opts)
      @diff = diff
      @opts = {
        :table_id_prefix => 'diff_json_view_0'
      }.merge(opts)
      @output = {
        :full  => "",
        :left  => "",
        :right => "",
        :sub_diffs => {}
      }

      calculate
    end

    def full
      return @output[:full]
    end

    def left
      return @output[:left]
    end

    def right
      return @output[:right]
    end

    private

    def calculate
      @output = {
        :full  => "<table id=\"#{@opts[:table_id_prefix]}_full\" class=\"diff-json-full-view\">\n",
        :left  => "<table id=\"#{@opts[:table_id_prefix]}_left\" class=\"diff-json-split-view-left\">\n",
        :right => "<table id=\"#{@opts[:table_id_prefix]}_right\" class=\"diff-json-split-view-right\">\n"
      }

      (0..(@diff[:full_diff][:old].length - 1)).each do |i|
        # Full, combined table output
        @output[:full]  += "<tr class=\"diff-json-view-line\">\n"
        @output[:full]  += "<td class=\"diff-json-view-line-operator\">#{@diff[:full_diff][:old][i][0].gsub(/\s/, '&nbsp;')}</td>\n"
        @output[:full]  += "<td class=\"diff-json-view-line-content #{content_highlight_class(:left, @diff[:full_diff][:old][i][0])}\">#{@diff[:full_diff][:old][i][1].gsub(/\s/, '&nbsp;')}</td>\n"
        @output[:full]  += "<td class=\"diff-json-view-column-break\"></td>\n"
        @output[:full]  += "<td class=\"diff-json-view-line-operator\">#{@diff[:full_diff][:new][i][0].gsub(/\s/, '&nbsp;')}</td>\n"
        @output[:full]  += "<td class=\"diff-json-view-line-content #{content_highlight_class(:right, @diff[:full_diff][:new][i][0])}\">#{@diff[:full_diff][:new][i][1].gsub(/\s/, '&nbsp;')}</td>\n"
        @output[:full]  += "</tr>\n"
        # Split, left side output
        @output[:left]  += "<tr class=\"diff-json-view-line\">\n"
        @output[:left]  += "<td class=\"diff-json-view-line-operator\">#{@diff[:full_diff][:old][i][0].gsub(/\s/, '&nbsp;')}</td>\n"
        @output[:left]  += "<td class=\"diff-json-view-line-content #{content_highlight_class(:left, @diff[:full_diff][:old][i][0])}\">#{@diff[:full_diff][:old][i][1].gsub(/\s/, '&nbsp;')}</td>\n"
        @output[:left]  += "</tr>\n"
        # Split, right side output
        @output[:right] += "<tr class=\"diff-json-view-line\">\n"
        @output[:right] += "<td class=\"diff-json-view-line-operator\">#{@diff[:full_diff][:new][i][0].gsub(/\s/, '&nbsp;')}</td>\n"
        @output[:right] += "<td class=\"diff-json-view-line-content #{content_highlight_class(:right, @diff[:full_diff][:new][i][0])}\">#{@diff[:full_diff][:new][i][1].gsub(/\s/, '&nbsp;')}</td>\n"
        @output[:right] += "</tr>\n"
      end

      @output[:full]  += "</table>\n"
      @output[:left]  += "</table>\n"
      @output[:right] += "</table>\n"
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
