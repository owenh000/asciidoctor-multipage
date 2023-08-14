lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "asciidoctor-multipage/version"

Gem::Specification.new do |s|
  s.authors = ['Owen T. Heisler']
  s.executables = ['asciidoctor-multipage']
  s.files = Dir['bin/*', 'lib/**/*.rb']
  s.name = 'asciidoctor-multipage'
  s.summary = 'Asciidoctor multipage HTML output extension'
  s.version = AsciidoctorMultipage::VERSION

  s.description = 'An Asciidoctor extension that generates HTML output using multiple pages'
  s.email = ['writer@owenh.net']
  s.homepage = 'https://github.com/owenh000/asciidoctor-multipage'
  s.license = 'MIT'
  s.metadata = {
    "bug_tracker_uri" => "https://github.com/owenh000/asciidoctor-multipage/issues",
    "homepage_uri" => s.homepage,
    "source_code_uri" => "https://github.com/owenh000/asciidoctor-multipage",
  }

  s.add_development_dependency 'appraisal'
  s.add_development_dependency 'bundler', '>= 2.2.18'
  s.add_development_dependency 'minitest', '~> 5'
  s.add_development_dependency 'rake', '~> 13'
  s.add_runtime_dependency 'asciidoctor', '>= 2.0.11', '< 2.1'
  s.date = '2023-08-14'
  s.required_ruby_version = '>= 2.5'
end
