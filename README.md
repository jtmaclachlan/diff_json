# diff_json

Takes two JSON documents and finds the difference between them. It can then return a JSON patch document, or generate an
element-based left/right diff view, similar to a git diff display. This repo contains both a Ruby gem and a Python
library, which have specific README files in their respective directories.

Two notes:
  * If all you need is quickly calculating a JSON patch, there are smaller, faster libraries out there, particularly in
    the Ruby realm. So, go with one of those if that's all you need. Due to the greater complexity of its diffing
    process, difference counting, and output capabilities, the diff finding process of this library is slower than many
    smaller libraries.
  * This library was originally written for a specific set of needs for an employer. So, if you're looking at the code
    and wondering "Why is that an option I would ever need?", blame that.
    