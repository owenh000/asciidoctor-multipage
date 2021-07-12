require 'minitest/autorun'
require 'asciidoctor'
require 'asciidoctor-multipage'

class AsciidoctorMultipageTest < Minitest::Test
  def test_black_box_docs
    dir = 'test/black-box-docs'
    test_only = ENV["BB_TEST_ONLY"]
    update_files = ENV["BB_UPDATE_FILES"].to_i
    Dir.foreach(dir) do |filename|
      next if filename == '.' or filename == '..'
      doc_path = File.join(dir, filename)
      next unless File.directory?(doc_path)
      next if test_only and test_only != filename
      adoc_path = File.join(doc_path, filename + '.adoc')
      doc = Asciidoctor.convert_file(adoc_path,
                                     :to_dir => 'test/out',
                                     :to_file => true,
                                     :header_footer => false,
                                     :backend => 'multipage_html5')
      pages = [doc] + doc.converter.pages
      pages.each do |page|
        page_path_before = File.join(doc_path, page.id + '.html')
        page_path_after = 'test/out/' + page.id + '.html'
        File.open(page_path_after) do |fa|
          if update_files > 0
            File.open(page_path_before, 'w') do |fb|
              fb.write(fa.read())
            end
          else
            File.open(page_path_before) do |fb|
              assert_equal fb.read(), fa.read()
            end
          end
        end
      end
    end
  end
end
