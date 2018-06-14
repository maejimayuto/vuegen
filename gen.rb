# encoding: utf-8

require 'fileutils'

pp ARGV

flow = File.read(ARGV[0])
flow << "\n" # insert \n for easy parsing
APP_TITLE = 'VUE_GEN_TITLE'


page_scans = flow.scan(/\[(.*)\]/).flatten

class Page
  attr_accessor :name, :page_body, :forms, :display_name, :body, :transitions
  def initialize(name, page_body, forms, display_name, body, transitions)
    @name = name
    @page_body = page_body
    @forms = forms
    @display_name = display_name
    @body = body
    @transitions = transitions
  end
end

class Generator
  def generate_scaffold
    FileUtils.rm_r('dst')
    FileUtils.cp_r('.scaffold', 'dst')
  end

  def rewrite_app_title
    app_file = 'dst/src/App.vue'
    FileUtils.cp('.scaffold/src/App.vue', app_file)
    app = File.read(app_file)
    app.gsub!('APP_TITLE', APP_TITLE)
    File.write(app_file, app)
  end

  def copy_routes
    routes_file = "dst/src/routes.js"
    FileUtils.cp('.scaffold/src/routes.js', routes_file)
  end

  def generate_route(page)
    routes_file = "dst/src/routes.js"
    routes = File.read(routes_file)

    import = "import #{page.name} from './#{page.name}';\n"

    components = "\n},\n{\n path: '/#{page.name.downcase}', component: #{page.name} },\n]"

    routes.gsub!(/\},\n\]/, components)

    File.write(routes_file, import + routes)
  end

  def generate_with(page)
    # page
    page_file =  "dst/src/#{page.name}.vue"
    FileUtils.cp('.scaffold/src/components/page.vue', page_file)
    pagesrc = File.read(page_file)
    pagesrc.gsub!('page', page.name.downcase)
    pagesrc.gsub!('PAGE_NAME', page.display_name) if page.display_name

    # BODY GENERATION
    body = page.body.map do |line|
      "<div>#{line}</div>"
    end
    pagesrc.gsub!('BODY', body.join("\n"))

    # FORM GENERATION 
    unless page.forms.flatten.empty?
      form_src = page.forms.map do |form|
        next if form.empty?
        form[2] = '' unless form[2]
        "<v-text-field v-model='#{form[3]}' label='#{form[4]}' #{form[2].delete('(').delete(')')}></v-text-field>"
      end
      form_src.unshift("<v-form>")
      form_src << "</v-form>"
      pagesrc.gsub!('===FORM===', form_src.join)
    else
      pagesrc.gsub!('===FORM===', '')
    end

    # TRANSITIONS GENERATION
    trs = page.transitions.map do |trn|
      next unless trn
      # TODO: structurize
      "<router-link to='/#{trn[2].downcase.strip}'>#{trn.first}</router-link>/"
    end
    pagesrc.gsub!('===LINK===', trs.join)

    File.write(page_file, pagesrc)

  end
end

gen = Generator.new
gen.generate_scaffold unless File.exist?('dst')
#gen.generate_scaffold 
gen.rewrite_app_title
gen.copy_routes

pages = []
page_scans.each do |page_scan|
  page_body = flow.scan(/^\[#{page_scan}\]$(.*?)(^\[|^\n)/m)
  transitions = []
 
  ## parse transitions
  tr_state = nil
  trs = []
  page_body.join.each_line do |tr|
    unless tr.scan('---').compact.empty?
      tr_state = :head
      next
    end
    case tr_state
    when :head
      trs = [tr]
      tr_state = :arrow
    when :arrow
      trs << tr.scan(/=({.*?})?=>(.*)/).flatten
      transitions << trs.flatten
      tr_state = :head
    end
  end

  forms = []
  page_body.join.each_line do |line|
    forms << line.scan(/\((.*?):(.*?)\)(\(.*?\))?(.*?):(.*?)$/).flatten
    break unless line.scan('---').empty?
  end

  body = []
  page_body.join.each_line do |line|
    next if line[0] == '('
    next if line[0] == 'T'
    break unless line.scan('---').empty?
    body << line
  end

  page = Page.new(
    page_scan,
    page_body,
    forms,
    page_body.to_s.scan(/Title\((.*?)\)/).flatten.first,
    body,
    transitions
  )
  gen.generate_route(page)
  gen.generate_with(page) 
end


