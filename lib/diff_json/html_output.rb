module DiffJson
  class HtmlOutput

    def initialize(diff, **opts)
      @diff = diff
      @opts = {
        :split    => false,
        :table_id_prefix => 'diff_json_view_0'
      }.merge(opts)

      calculate
    end

    def output
      return @output
    end

    def left
      return @output[:left] if @opts[:split]

      raise 'Method `#left` is only available for split output'
    end

    def right
      return @output[:right] if @opts[:split]

      raise 'Method `#right` is only available for split output'
    end

    private

    def calculate
      if @opts[:split]
        @output = {
          :left  => "<table id=\"#{@opts[:table_id_prefix]}_left\" class=\"diff-json-split-view-left\">\n",
          :right => "<table id=\"#{@opts[:table_id_prefix]}_right\" class=\"diff-json-split-view-right\">\n"
        }

        (0..(@diff[:full_diff][:old].length - 1)).each do |i|
          @output[:left]  += "<tr class=\"diff-json-view-line\">\n"
          @output[:left]  += "<td class=\"diff-json-view-line-operator\">#{@diff[:full_diff][:old][i][0].gsub(/\s/, '&nbsp;')}</td>\n"
          @output[:left]  += "<td class=\"diff-json-view-line-content #{content_highlight_class(:left, @diff[:full_diff][:old][i][0])}\">#{@diff[:full_diff][:old][i][1].gsub(/\s/, '&nbsp;')}</td>\n"
          @output[:left]  += "</tr>\n"
          @output[:right] += "<tr class=\"diff-json-view-line\">\n"
          @output[:right] += "<td class=\"diff-json-view-line-operator\">#{@diff[:full_diff][:new][i][0].gsub(/\s/, '&nbsp;')}</td>\n"
          @output[:right] += "<td class=\"diff-json-view-line-content #{content_highlight_class(:right, @diff[:full_diff][:new][i][0])}\">#{@diff[:full_diff][:new][i][1].gsub(/\s/, '&nbsp;')}</td>\n"
          @output[:right] += "</tr>\n"
        end

        @output[:left]  += "</table>\n"
        @output[:right] += "</table>\n"
      else
        @output = "<table id=\"#{@opts[:table_id_prefix]}_full\" class=\"diff-json-view\">\n"

        (0..(@diff[:full_diff][:old].length - 1)).each do |i|
          @output += "<tr class=\"diff-json-view-line\">\n"
          @output += "<td class=\"diff-json-view-line-operator\">#{@diff[:full_diff][:old][i][0].gsub(/\s/, '&nbsp;')}</td>\n"
          @output += "<td class=\"diff-json-view-line-content #{content_highlight_class(:left, @diff[:full_diff][:old][i][0])}\">#{@diff[:full_diff][:old][i][1].gsub(/\s/, '&nbsp;')}</td>\n"
          @output += "<td class=\"diff-json-view-line-operator\">#{@diff[:full_diff][:new][i][0].gsub(/\s/, '&nbsp;')}</td>\n"
          @output += "<td class=\"diff-json-view-line-content #{content_highlight_class(:right, @diff[:full_diff][:new][i][0])}\">#{@diff[:full_diff][:new][i][1].gsub(/\s/, '&nbsp;')}</td>\n"
          @output += "</tr>\n"
        end

        @output += "</table>\n"
      end
    end

    def content_highlight_class(side, operator)
      if operator == '-'
        return 'diff-json-content-del'
      elsif operator == '+'
        return 'diff-json-content-ins'
      elsif operator == 'M'
        return side == :left ? 'diff-json-content-del' : 'diff-json-content-ins'
      else
        return nil
      end
    end
  end
end
