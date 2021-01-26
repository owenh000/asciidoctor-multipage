require 'minitest/autorun'
require 'asciidoctor'
require 'asciidoctor-multipage'

class AsciidoctorMultipageTest < Minitest::Test
  def test_sample_document
    doc = Asciidoctor.convert_file('test/fixtures/sample.adoc',
                                   :to_dir => 'test/out',
                                   :to_file => true,
                                   :header_footer => false,
                                   :backend => 'multipage_html5')
    pages = [doc] + doc.converter.pages
    pages.each do |page|
      page_path_before = 'test/fixtures/' + page.id + '.html'
      page_path_after = 'test/out/' + page.id + '.html'
      File.open(page_path_before) do |fb|
        File.open(page_path_after) do |fa|
          assert_equal fb.read(), fa.read()
        end
      end
    end
  end
end
