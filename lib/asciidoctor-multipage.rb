# coding: utf-8

require 'asciidoctor'
require 'asciidoctor/converter/html5'

class Asciidoctor::AbstractBlock
  # Allow navigation links HTML to be saved and retrieved
  attr_accessor :nav_links
end

class Asciidoctor::AbstractNode
  # Is this node (self) of interest when generating a TOC for node?
  def related_to?(node)
    return true if self.level == 0
    node_tree = []
    current = node
    while current.class != Asciidoctor::Document
      node_tree << current
      current = current.parent
    end
    node_tree << current
    if node_tree.include?(self) ||
       node_tree.include?(self.parent)
      return true
    end
    # If this is a leaf page, include all child sections in TOC
    if node.mplevel == :leaf
      self_tree = []
      current = self
      while current && current.level >= node.level
        self_tree << current
        current = current.parent
      end
      return true if self_tree.include?(node)
    end
    return false
  end
end

class Asciidoctor::Document
  # Allow writing to the :catalog attribute in order to duplicate refs list to
  # new pages
  attr_writer :catalog

  # Allow the section type to be saved (for when a Section becomes a Document)
  attr_accessor :mplevel

  # Allow the current Document to be marked as processed by this extension
  attr_accessor :processed

  # Allow saving of section number for use later. This is necessary for when a
  # branch or leaf Section becomes a Document during chunking and ancestor
  # nodes are no longer accessible.
  attr_writer :sectnum

  # A pointer to the original converter (first converter instantiated to
  # convert the original document). As we create additional documents
  # ourselves, AsciiDoctor will instantiate additional instances of
  # MultipageHtml5Converter for each created document. These instances need
  # to share state, so they can use the original converter instance
  # for that purpose.
  attr_accessor :mp_root

  # Override the AbstractBlock sections?() check to enable the Table Of
  # Contents. This extension may generate short pages that would normally have
  # no need for a TOC. However, we override the Html5Converter outline() in
  # order to generate a custom TOC for each page with entries that span the
  # entire document.
  def sections?
    return true
  end

  # Return the saved section number for this Document object (which was
  # originally a Section)
  def sectnum(delimiter = nil, append = nil)
    @sectnum
  end
end

class Asciidoctor::Section
  # Allow the section type (:root, :branch, :leaf) to be saved for each section
  attr_accessor :mplevel

  # Extend sectnum() to use the Document's saved sectnum. Document objects
  # normally do not have sectnums, but here Documents are generated from
  # Sections. The sectnum is saved in section() below.
  def sectnum(delimiter = '.', append = nil)
    append ||= (append == false ? '' : delimiter)
    if @level > 1 and @parent.class == Asciidoctor::Section ||
                      (@mplevel && @parent.class == Asciidoctor::Document)
        %(#{@parent.sectnum(delimiter)}#{@numeral}#{append})
    else
      %(#{@numeral}#{append})
    end
  end
end

class MultipageHtml5Converter < Asciidoctor::Converter::Html5Converter
  include Asciidoctor
  include Asciidoctor::Converter
  include Asciidoctor::Writer

  register_for 'multipage_html5'

  attr_accessor :pages

  # contains the entire outline of the top-level document, used
  # as a guide-rail for creating TOC elements for documents we
  # split off. Only expected to be set in the top-level converter
  # (see AsciiDoctor::Document::mp_root)
  attr_accessor :full_outline

  def initialize(backend, opts = {})
    @xml_mode = false
    @void_element_slash = nil
    super
    @stylesheets = Stylesheets.instance
    @pages = []
  end

  # Add navigation links to the page (from nav_links)
  def add_nav_links(page)
    block = Asciidoctor::Block.new(parent = page,
                                   :paragraph,
                                   opts = {:source => page.nav_links})
    block.add_role('nav-footer')
    page << block
  end

  # ensures that the AsciiDoctor::Document::mp_root is correctly
  # set on the document object. The variable could have already been
  # set if we created the document ourselves
  # (see ::MultipageHtml5Converter::convert_section), in which case it's
  # not changed. If the documented is "nested", then we expect the parent
  # document to already have it set. Otherwise, this is expected to be
  # a top-level document, and we assign ourselves as its original converter.
  def check_root(doc)
    unless doc.mp_root
      if doc.nested?
        doc.mp_root = doc.parent_document.mp_root
      else
        doc.mp_root = self
      end
    end
  end

  # Process Document (either the original full document or a processed page)
  def convert_document(node)

    # make sure document has original converter reference
    check_root(node)

    if node.processed
      # This node (an individual page) can now be handled by
      # Html5Converter.
      super
    else
      # This node is the original full document which has not yet been
      # processed; this is the entry point for the extension.

      # Save a reference to the root document in the converter
      # instance. This will be used to set the @requires_stylesheet
      # variable on the root document in the write method.
      @root_doc = node

      # Turn off extensions to avoid running them twice.
      # FIXME: DocinfoProcessor, InlineMacroProcessor, and Postprocessor
      # extensions should be retained. Is this possible with the API?
      #Asciidoctor::Extensions.unregister_all

      # Check toclevels and multipage-level attributes
      mplevel = node.document.attr('multipage-level', 1).to_i
      toclevels = node.document.attr('toclevels', 2).to_i
      if toclevels < mplevel
        logger.warn 'toclevels attribute should be >= multipage-level'
      end
      if mplevel < 0
        logger.warn 'multipage-level attribute must be >= 0'
        mplevel = 0
      end
      node.document.set_attribute('multipage-level', mplevel.to_s)

      # Set multipage chunk types
      set_multipage_attrs(node)

      # FIXME: This can result in a duplicate ID without a warning.
      # Set the "id" attribute for the Document, using the "docname", which is
      # based on the file name. Then register the document ID using the
      # document title. This allows cross-references to refer to (1) the
      # top-level document itself or (2) anchors in top-level content (blocks
      # that are specified before any sections).
      node.id = node.attributes['docname']
      node.register(:refs, [node.id,
                            (Inline.new(parent = node,
                                        context = :anchor,
                                        text = node.doctitle,
                                        opts = {:type => :ref,
                                                :id => node.id})),
                            node.doctitle])

      # Generate navigation links for all pages
      generate_nav_links(node)

      # Create and save a skeleton document for generating the TOC lists,
      # but don't attempt to create outline for nested documents.
      unless node.nested?
        # if the original converter has the @full_outline set already, we are about
        # to replace it. That's not supposed to happen, and probably means we encountered
        # a document structure we aren't prepared for. Log an error and move on.
        logger.error "Regenerating document outline, something wrong?" if node.mp_root.full_outline
        node.mp_root.full_outline = new_outline_doc(node)
      end

      # Save the document catalog to use for each part/chapter page.
      @catalog = node.catalog

      # Retain any book intro blocks, delete others, and add a list of sections
      # for the book landing page.
      parts_list = Asciidoctor::List.new(node, :ulist)
      node.blocks.delete_if do |block|
        if block.context == :section
          part = block
          part.convert
          text = %(<<#{part.id},#{part.captioned_title}>>)
          if (desc = block.attr('desc')) then text << %( – #{desc}) end
          parts_list << Asciidoctor::ListItem.new(parts_list, text)
        end
      end
      node << parts_list

      # Add navigation links
      add_nav_links(node)

      # Mark page as processed and return converted result
      node.processed = true
      node.convert
    end
  end

  # Process Document in embeddable mode (either the original full document or a
  # processed page)
  def convert_embedded(node)
    # make sure document has original converter reference
    check_root(node)
    if node.processed
      # This node (an individual page) can now be handled by
      # Html5Converter.
      super
    else
      # This node is the original full document which has not yet been
      # processed; it can be handled by convert_document().
      convert_document(node)
    end
  end

  # Generate navigation links for all pages in document; save HTML to nav_links
  def generate_nav_links(doc)
    pages = doc.find_by(context: :section) {|section|
      [:root, :branch, :leaf].include?(section.mplevel)}
    pages.insert(0, doc)
    pages.each do |page|
      page_index = pages.find_index(page)
      links = []
      if page.mplevel != :root
        previous_page = pages[page_index-1]
        parent_page = page.parent
        home_page = doc
        # NOTE: There are some non-breaking spaces (U+00A0) below, in
        # the "links <<" lines and "links.join" line.
        if previous_page != parent_page
          links << %(← #{doc.attr('multipage-nav-previous-label') || "Previous"}: <<#{previous_page.id},#{previous_page.captioned_title}>>)
        end
        links << %(↑ #{doc.attr('multipage-nav-up-label') || "Up"}: <<#{parent_page.id},#{parent_page.captioned_title}>>)
        links << %(⌂ #{doc.attr('multipage-nav-home-label') || "Home"}: <<#{home_page.id},#{home_page.captioned_title}>>) if home_page != parent_page
      end
      if page_index != pages.length-1
        next_page = pages[page_index+1]
        links << %(#{doc.attr('multipage-nav-next-label') || "Next"}: <<#{next_page.id},#{next_page.captioned_title}>> →)
      end
      block = Asciidoctor::Block.new(parent = doc,
                                     context = :paragraph,
                                     opts = {:source => links.join(' | '),
                                             :subs => :default})
      page.nav_links = block.content
    end
    return
  end

  # Generate the actual HTML outline for the TOC. This method is analogous to
  # Html5Converter convert_outline().
  def generate_outline(node, opts = {})
    # Do the same as Html5Converter convert_outline() here
    return unless node.sections? && node.sections.length > 0
    sectnumlevels = opts[:sectnumlevels] || (node.document.attributes['sectnumlevels'] || 3).to_i
    toclevels = opts[:toclevels] || (node.document.attributes['toclevels'] || 2).to_i
    sections = node.sections
    result = [%(<ul class="sectlevel#{sections[0].level}">)]
    sections.each do |section|
      slevel = section.level
      if section.caption
        stitle = section.captioned_title
      elsif section.numbered && slevel <= sectnumlevels
        if slevel < 2 && node.document.doctype == 'book'
          if section.sectname == 'chapter'
            stitle =  %(#{(signifier = node.document.attributes['chapter-signifier']) ? "#{signifier} " : ''}#{section.sectnum} #{section.title})
          elsif section.sectname == 'part'
            stitle =  %(#{(signifier = node.document.attributes['part-signifier']) ? "#{signifier} " : ''}#{section.sectnum nil, ':'} #{section.title})
          else
            stitle = %(#{section.sectnum} #{section.title})
          end
        else
          stitle = %(#{section.sectnum} #{section.title})
        end
      else
        stitle = section.title
      end
      stitle = stitle.gsub DropAnchorRx, '' if stitle.include? '<a'

      # But add a special style for current page in TOC
      if section.id == opts[:page_id]
        stitle = %(<span class="toc-current">#{stitle}</span>)
      end

      # And we also need to find the parent page of the target node
      current = section
      until current.mplevel != :content
        current = current.parent
      end
      parent_chapter = current

      # If the target is the top-level section of the parent page, there is no
      # need to include the anchor.
      if parent_chapter.id == section.id
        link = %(#{parent_chapter.id}.html)
      else
        link = %(#{parent_chapter.id}.html##{section.id})
      end
      result << %(<li><a href="#{link}">#{stitle}</a>)

      # Finish in a manner similar to Html5Converter convert_outline()
      if slevel < toclevels &&
         (child_toc_level = generate_outline section,
                                             toclevels: toclevels,
                                             secnumlevels: sectnumlevels,
                                             page_id: opts[:page_id])
        result << child_toc_level
      end
      result << '</li>'
    end
    result << '</ul>'
    result.join LF
  end

  # Include chapter pages in cross-reference links. This method overrides for
  # the :xref node type only.
  def convert_inline_anchor(node)
    if node.type == :xref
      # This is the same as super...
      if (path = node.attributes['path'])
        attrs = (append_link_constraint_attrs node, node.role ? [%( class="#{node.role}")] : []).join
        text = node.text || path
      else
        attrs = node.role ? %( class="#{node.role}") : ''
        unless (text = node.text)
          if AbstractNode === (ref = (@refs ||= node.document.catalog[:refs])[refid = node.attributes['refid']] || (refid.nil_or_empty? ? (top = get_root_document node) : nil))
            if (@resolving_xref ||= (outer = true)) && outer
              if (text = ref.xreftext node.attr 'xrefstyle', nil, true)
                text = text.gsub DropAnchorRx, '' if text.include? '<a'
              else
                text = top ? '[^top]' : %([#{refid}])
              end
              @resolving_xref = nil
            else
              text = top ? '[^top]' : %([#{refid}])
            end
          else
            text = %([#{refid}])
          end
        end
      end

      # But we also need to find the parent page of the target node.
      current = node.document.catalog[:refs][node.attributes['refid']]
      until current.respond_to?(:mplevel) && current.mplevel != :content
        return %(<a href="#{node.target}"#{attrs}>#{text}</a>) if !current
        current = current.parent
      end
      parent_page = current

      # If the target is the top-level section of the parent page, there is no
      # need to include the anchor.
      if "##{parent_page.id}" == node.target
        target = "#{parent_page.id}.html"
      else
        target = "#{parent_page.id}.html#{node.target}"
      end

      %(<a href="#{target}"#{attrs}>#{text}</a>)
    else
      # Other anchor types can be handled as normal.
      super
    end
  end

  # From node, create a skeleton document that will be used to generate the
  # TOC. This is first used to create a full skeleton (@full_outline) from the
  # original document (for_page=nil). Then it is used for each individual page
  # to create a second skeleton from the first. In this way, TOC entries are
  # included that are not part of the current page, or excluded if not
  # applicable for the current page.
  def new_outline_doc(node, new_parent:nil, for_page:nil)
    if node.class == Document
      new_document = Document.new([], {:doctype => node.doctype})
      new_document.mplevel = node.mplevel
      new_document.id = node.id
      new_document.update_attributes(node.attributes)
      new_parent = new_document
      node.sections.each do |section|
        new_outline_doc(section, new_parent: new_parent,
                        for_page: for_page)
      end
    # Include the node if either (1) we are creating the full skeleton from the
    # original document or (2) the node is applicable to the current page.
    elsif !for_page ||
          node.related_to?(for_page)
      new_section = Section.new(parent = new_parent,
                                level = node.level,
                                numbered = node.numbered)
      new_section.id = node.id
      new_section.sectname = node.sectname
      new_section.caption = node.caption
      new_section.title = node.instance_variable_get(:@title)
      new_section.mplevel = node.mplevel
      new_parent << new_section
      new_parent.sections.last.numeral = node.numeral
      new_parent = new_section
      node.sections.each do |section|
        new_outline_doc(section, new_parent: new_parent,
                        for_page: for_page)
      end
    end
    return new_document
  end

  # Override Html5Converter convert_outline() to return a custom TOC
  # outline.
  def convert_outline(node, opts = {})
    doc = node.document
    # Find this node in the @full_outline skeleton document
    page_node = doc.mp_root.full_outline.find_by(id: node.id).first
    # Create a skeleton document for this particular page
    custom_outline_doc = new_outline_doc(doc.mp_root.full_outline, for_page: page_node)
    opts[:page_id] = node.id
    # Generate an extra TOC entry for the root page. Add additional styling if
    # the current page is the root page.
    root_file = %(#{doc.attr('docname')}#{doc.attr('outfilesuffix')})
    root_link = %(<a href="#{root_file}">#{doc.doctitle}</a>)
    classes = ['toc-root']
    classes << 'toc-current' if node.id == doc.attr('docname')
    root = %(<span class="#{classes.join(' ')}">#{root_link}</span>)
    # Create and return the HTML
    %(<p>#{root}</p>#{generate_outline(custom_outline_doc, opts)})
  end

  # Change node parent to new parent recursively
  def reparent(node, parent)
    node.parent = parent
    if node.context == :dlist
      node.find_by(context: :list_item).each do |block|
        reparent(block, node)
      end
    else
      node.blocks.each do |block|
        reparent(block, node)
        if block.context == :table
          block.columns.each do |col|
            col.parent = col.parent
          end
          block.rows.body.each do |row|
            row.each do |cell|
              cell.parent = cell.parent
            end
          end
        end
      end
    end
  end

  # Process a Section. Each Section will either be split off into its own page
  # or processed as normal by Html5Converter.
  def convert_section(node)
    doc = node.document
    if doc.processed
      # This node can now be handled by Html5Converter.
      super
    else
      # This node is from the original document and has not yet been processed.

      # Create a new page for this section
      page = Asciidoctor::Document.new([],
                                       {:attributes => doc.attributes.clone,
                                        :doctype => doc.doctype,
                                        :header_footer => !doc.attr?(:embedded),
                                        :safe => doc.safe})
      # Retain webfonts attribute (why is doc.attributes.clone not adequate?)
      page.set_attr('webfonts', doc.attr(:webfonts))
      # Save sectnum for use later (a Document object normally has no sectnum)
      if node.parent.respond_to?(:numbered) && node.parent.numbered
        page.sectnum = node.parent.sectnum
      end

      page.mp_root = doc.mp_root

      # Process node according to mplevel
      if node.mplevel == :branch
        # Retain any part intro blocks, delete others, and add a list
        # of sections for the part landing page.
        chapters_list = Asciidoctor::List.new(node, :ulist)
        node.blocks.delete_if do |block|
          if block.context == :section
            chapter = block
            chapter.convert
            text = %(<<#{chapter.id},#{chapter.captioned_title}>>)
            # NOTE, there is a non-breaking space (Unicode U+00A0) below.
            if desc = block.attr('desc') then text << %( – #{desc}) end
            chapters_list << Asciidoctor::ListItem.new(chapters_list, text)
            true
          end
        end
        # Add chapters list to node, reparent node to new page, add
        # node to page, mark as processed, and add page to @pages.
        node << chapters_list
        reparent(node, page)
        page.blocks << node
      else # :leaf
        # Reparent node to new page, add node to page, mark as
        # processed, and add page to @pages.
        reparent(node, page)
        page.blocks << node
      end

      # Add navigation links using saved HTML
      page.nav_links = node.nav_links
      add_nav_links(page)

      # Mark page as processed and add to collection of pages
      @pages << page
      page.id = node.id
      page.catalog = @catalog
      page.mplevel = node.mplevel
      page.processed = true
    end
  end

  # Add multipage attribute to all sections in node, recursively.
  def set_multipage_attrs(node)
    doc = node.document
    node.mplevel = :root if node.class == Asciidoctor::Document
    node.sections.each do |section|
      # Check custom multipage-level attribute on section; warn and
      # discard if invalid
      if section.attr?('multipage-level', nil, false) &&
         section.attr('multipage-level').to_i <
         node.attr('multipage-level').to_i
        logger.warn %(multipage-level value specified for "#{section.id}" ) +
                    %(section cannot be less than the parent section value)
        section.set_attr('multipage-level', nil)
      end
      # Propagate custom multipage-level value to child node
      if !section.attr?('multipage-level', nil, false) &&
         node.attr('multipage-level') != doc.attr('multipage-level')
        section.set_attr('multipage-level', node.attr('multipage-level'))
      end
      # Set section type
      if section.level < section.attr('multipage-level', nil, true).to_i
        section.mplevel = :branch
      elsif section.level == section.attr('multipage-level', nil, true).to_i
        section.mplevel = :leaf
      else
        section.mplevel = :content
      end
      # Set multipage attribute on child sections now.
      set_multipage_attrs(section)
    end
  end

  # Convert each page and write it to file. Use filenames based on IDs.
  def write(output, target)
    # Write primary (book) landing page
    ::File.open(target, 'w') do |f|
      f.write(output)
    end
    # Write remaining part/chapter pages
    outdir = ::File.dirname(target)
    ext = ::File.extname(target)
    @pages.each do |doc|
      chapter_target = doc.id + ext
      outfile = ::File.join(outdir, chapter_target)
      ::File.open(outfile, 'w') do |f|
        f.write(doc.convert)
      end
      if (doc.syntax_highlighter and
          doc.syntax_highlighter.write_stylesheet? doc)
        root_doc = doc.mp_root.instance_variable_get(:@root_doc)
        root_doc.syntax_highlighter.instance_variable_set(
          :@requires_stylesheet, true)
      end
    end
  end
end

class MultipageHtml5CSS < Asciidoctor::Extensions::DocinfoProcessor
  use_dsl
  at_location :head

  def process doc
    # Disable this entirely if the multipage-disable-css attribute is set
    if doc.attr('multipage-disable-css')
      return
    end
    css = []
    # Style Table Of Contents entry for current page
    css << %(.toc-current{font-weight: bold;})
    # Style Table Of Contents entry for root page
    css << %(.toc-root{font-family: "Open Sans","DejaVu Sans",sans-serif;
                       font-size: 0.9em;})
    # Style navigation bar at bottom of each page
    css << %(#content{display: flex; flex-direction: column; flex: 1 1 auto;}
             .nav-footer{text-align: center; margin-top: auto;}
             .nav-footer > p > a {white-space: nowrap;})
    %(<style>#{css.join(' ')}</style>)
  end
end

Asciidoctor::Extensions.register do
  docinfo_processor MultipageHtml5CSS
end
