# _plugins/details_tag.rb

module Jekyll
	module Tags
	  class DetailsTag < Liquid::Block
  
		def initialize(tag_name, markup, tokens)
		  super
		  @caption = markup
		end
  
		def render(context)
		  site = context.registers[:site]
		  converter = site.find_converter_instance(::Jekyll::Converters::Markdown)
		  caption = converter.convert(@caption).gsub(/<\/?p[^>]*>/, '').chomp
		  body = converter.convert(super(context))
		  "<div class=\"log\"><details open=true><summary><span>Hide #{caption}</span></summary>#{body}</details></div>"
		end
  
	  end
	end
  end
  
  Liquid::Template.register_tag('codelog', Jekyll::Tags::DetailsTag)