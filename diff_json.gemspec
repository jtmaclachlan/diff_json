Gem::Specification.new do |spec|
  # Basic Gem Description
  spec.name          = "diff_json"
  spec.version       = "0.0.1"
  spec.date          = "2018-08-10"
  spec.summary       = "Diffs two JSON objects and returns a left/right diff view, similar to the command line `diff` utility"
  spec.description   = spec.summary
  spec.authors       = ["Josh MacLachlan"]
  spec.email         = "jmaclachlan@aprriss.com"
  spec.homepage      = "https://stash.sdlc.appriss.com/users/jmaclachlan_appriss.com/repos/rubygem.diff-a-hash/browse"
  spec.require_paths = ["lib"]
  spec.files         = Dir['lib/**/*.rb']
  spec.license       = "GPL-2"
end
