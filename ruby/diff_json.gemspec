Gem::Specification.new do |spec|
  # Basic Gem Description
  spec.name          = "diff_json"
  spec.version       = "1.1.0"
  spec.date          = "2021-06-10"
  spec.summary       = "Diffs two JSON objects and returns a JSON patch, or a left/right diff view, similar to the command line `diff` utility"
  spec.description   = spec.summary
  spec.authors       = ["Josh MacLachlan"]
  spec.email         = "josh.t.maclachlan@gmail.com"
  spec.homepage      = "https://github.com/jtmaclachlan/diff_json"
  spec.require_paths = ["lib"]
  spec.files         = Dir['lib/**/*.rb']
  spec.license       = "GPL-2.0"

  spec.add_runtime_dependency 'require_all'
end
