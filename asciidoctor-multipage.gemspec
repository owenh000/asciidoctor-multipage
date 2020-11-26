Gem::Specification.new do |s|
  s.authors = ['Owen T. Heisler']
  s.files = ['lib/asciidoctor-multipage.rb']
  s.name = 'asciidoctor-multipage'
  s.summary = 'Asciidoctor multipage HTML output extension'
  s.version = '0.0.1.dev'

  s.description = 'An Asciidoctor extension that generates HTML output using multiple pages'
  s.email = ['writer@owenh.net']
  s.homepage = 'https://github.com/owenh000/asciidoctor-multipage'
  s.license = 'MIT'
  s.metadata = {
    "bug_tracker_uri" => "https://github.com/owenh000/asciidoctor-multipage/issues",
  }

  s.add_development_dependency 'bundler'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'rake'
  s.add_runtime_dependency 'asciidoctor', '1.5.7.1'
  s.date = '2020-11-26'
  s.required_ruby_version = '>= 2.5'
end
