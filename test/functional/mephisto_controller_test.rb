require File.dirname(__FILE__) + '/../test_helper'
require_dependency 'mephisto_controller'

# Re-raise errors caught by the controller.
class MephistoController; def rescue_action(e) raise e end; end

class MephistoControllerTest < Test::Unit::TestCase
  fixtures :contents, :sections, :assigned_sections, :sites, :users

  def setup
    prepare_theme_fixtures
    @controller = MephistoController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    host! 'test.com'
  end

  def test_should_list_on_home
    dispatch
    assert_dispatch_action :list
    assert_preferred_template :home
    assert_layout_template    :layout
    assert_template_type      :section
    assert_response :success
    assert_equal sites(:first),                            assigns(:site)
    assert_equal sections(:home),                          assigns(:section)
    assert_equal [contents(:welcome), contents(:another)], assigns(:articles)
    assert_equal sites(:first),                            liquid(:site).source
    assert_equal sections(:home),                          liquid(:section).source
    assert_equal sections(:home),                          liquid(:site).current_section.source
    assert_equal [contents(:welcome), contents(:another)], liquid(:articles).collect(&:source)
    assert liquid(:section).current
  end

  def test_should_show_paged_home
    host! 'cupcake.com'
    dispatch
    assert_dispatch_action :page
    assert_preferred_template :home
    assert_layout_template    :layout
    assert_template_type      :page
    assert_equal sites(:hostess),            assigns(:site)
    assert_equal sections(:cupcake_home),    assigns(:section)
    assert_equal contents(:cupcake_welcome), assigns(:article)
    assert_nil assigns(:articles)
    assert liquid(:section).current
    assert_equal sections(:cupcake_home), liquid(:site).current_section.source
    assert_response :success
  end

  def test_should_show_error_on_bad_blog_url
    dispatch 'foobar/basd'
    assert_dispatch_action :error
    assert_preferred_template :error
    assert_layout_template    :layout
    assert_template_type      :error
    assert_equal sites(:first), assigns(:site)
    assert_response :missing
  end

  def test_should_show_error_on_bad_paged_url
    host! 'cupcake.com'
    dispatch 'foobar/basd'
    assert_dispatch_action :error
    assert_equal sites(:hostess), assigns(:site)
    assert_equal sections(:cupcake_home),         assigns(:section)
    assert_response :missing
  end

  def test_should_show_error_on_bad_paged_section
    host! 'cupcake.com'
    dispatch 'about/foo'
    assert_dispatch_action :page
    assert_equal sites(:hostess), assigns(:site)
    assert_equal sections(:cupcake_about),         assigns(:section)
    assert_response :missing
  end

  def test_should_show_correct_feed_url
    dispatch
    assert_dispatch_action :list
    assert_tag :tag => 'link', :attributes => { :type => 'application/atom+xml', :href => '/feed/atom.xml' }
  end

  def test_list_by_sections
    dispatch 'about'
    assert_equal sites(:first), assigns(:site)
    assert_equal sections(:about), assigns(:section)
    assert_equal contents(:welcome), assigns(:article)
    assert_preferred_template :page
    assert_layout_template    :layout
    assert_template_type      :page
    assert_dispatch_action    :page
  end
  
  def test_list_by_site_sections
    host! 'cupcake.com'
    dispatch 'about'
    assert_equal sites(:hostess), assigns(:site)
    assert_equal sections(:cupcake_about), assigns(:section)
    assert_equal contents(:cupcake_welcome), assigns(:article)
  end

  def test_should_show_page
    dispatch 'about/the-site-map'
    assert_equal sections(:about), assigns(:section)
    assert_equal contents(:site_map), assigns(:article)
    assert_dispatch_action :page
  end

  def test_should_render_liquid_templates_on_home
    dispatch
    assert_tag 'h1', :content => 'This is the layout'
    assert_tag 'p',  :content => 'home'
    assert_tag 'h2', :content => contents(:welcome).title
    assert_tag 'h2', :content => contents(:another).title
    assert_tag 'p',  :content => contents(:welcome).excerpt
    assert_tag 'p',  :content => contents(:another).body
  end

  def test_should_show_time_in_correct_timezone
    dispatch
    assert_tag 'span', :content => assigns(:site).timezone.utc_to_local(contents(:welcome).published_at).to_s(:standard)
  end

  def test_should_render_liquid_templates_by_sections
    dispatch 'about'
    assert_dispatch_action :page
    assert_tag :tag => 'h1', :content => contents(:welcome).title
  end

  def test_should_search_entries
    dispatch 'search', :q => 'another'
    assert_dispatch_action :search
    assert_equal [contents(:another)], assigns(:articles)
    assert_equal sites(:first).articles_per_page, liquid(:site).before_method(:articles_per_page)
    assert_equal 'another', liquid(:search_string)
    assert_equal 1, liquid(:search_count)
    assert_preferred_template :search
    assert_layout_template    :layout
    assert_template_type      :search
  end

  def test_should_search_and_not_find_draft
    dispatch 'search', :q => 'draft'
    assert_dispatch_action :search
    assert_equal [], assigns(:articles)
    assert_preferred_template :search
    assert_layout_template    :layout
    assert_template_type      :search
  end

  def test_should_search_and_not_find_future
    dispatch 'search', :q => 'future'
    assert_dispatch_action :search
    assert_equal [], assigns(:articles)
    assert_preferred_template :search
    assert_layout_template    :layout
    assert_template_type      :search
  end

  def test_should_show_entry
    date = 3.days.ago
    dispatch "#{date.year}/#{date.month}/#{date.day}/welcome-to-mephisto"
    assert_equal contents(:welcome).to_liquid['id'], assigns(:article)['id']
    assert_preferred_template :single
    assert_layout_template    :layout
    assert_template_type      :single
    assert_dispatch_action    :single
  end
  
  def test_should_show_site_entry
    host! 'cupcake.com'
    date = 3.days.ago
    dispatch "#{contents(:cupcake_welcome).year}/#{contents(:cupcake_welcome).month}/#{contents(:cupcake_welcome).day}/#{contents(:cupcake_welcome).permalink}"
    assert_dispatch_action :single
    assert_template_type   :single
    assert_equal contents(:cupcake_welcome).to_liquid['id'], assigns(:article)['id']
  end
  
  def test_should_show_error_on_bad_permalink
    dispatch "#{contents(:cupcake_welcome).year}/#{contents(:cupcake_welcome).month}/#{contents(:cupcake_welcome).day}/welcome-to-paradise"
    assert_response :missing
    assert_dispatch_action :single
  end
  
  def test_should_show_navigation_on_paged_sections
    dispatch 'about'
    assert_tag 'ul', :attributes => { :id => 'nav' },
               :children => { :count => 3, :only => { :tag => 'li' } }
    assert_tag 'ul', :attributes => { :id => 'nav' },
               :descendant => { :tag => 'a', :attributes => { :class => 'selected' } }
    assert_tag 'a',  :attributes => { :class => 'selected' }, :content => 'Home'
  end

  def test_should_set_home_page_on_paged_sections
    dispatch 'about'
    assert_equal 3, liquid(:pages).size
    [true, false, false].each_with_index do |expected, i|
      assert_equal expected, liquid(:pages)[i][:is_page_home]
    end
  end

  def test_should_set_paged_permalinks
    dispatch 'about'
    assert_tag 'a', :attributes => { :href => '/about', :class => 'selected' }, :content => 'Home'
    assert_tag 'a', :attributes => { :href => '/about/about-this-page'       }, :content => 'About'
    assert_tag 'a', :attributes => { :href => '/about/the-site-map'          }, :content => 'The Site Map'
  end

  def test_should_set_paged_permalinks
    dispatch 'about/the-site-map'
    assert_tag 'a', :attributes => { :href => '/about'                                    }, :content => 'Home'
    assert_tag 'a', :attributes => { :href => '/about/about-this-page'                    }, :content => 'About'
    assert_tag 'a', :attributes => { :href => '/about/the-site-map', :class => 'selected' }, :content => 'The Site Map'
  end

  def test_should_sanitize_comment
    date = 3.days.ago
    dispatch "#{date.year}/#{date.month}/#{date.day}/welcome-to-mephisto"
    evil = %(<p>rico&#8217;s evil <script>hi</script> and <a onclick="foo" href="#">linkage</a></p>)
    good = %(<p>rico&#8217;s evil &lt;script>hi&lt;/script> and <a href='#'>linkage</a></p>)
    assert !@response.body.include?(evil), "includes unsanitized code"
    assert  @response.body.include?(good), "does not include sanitized code"
  end

  def test_should_show_comments_form
    date = 3.days.ago
    dispatch "#{date.year}/#{date.month}/#{date.day}/welcome-to-mephisto"
    assert_dispatch_action :single
    assert_tag 'form', :attributes => { :id => 'comment-form', :action => "#{contents(:welcome).full_permalink}/comment#comment-form"}
    assert_tag :tag => 'form',     :descendant => { 
               :tag => 'input',    :attributes => { :type => 'text', :id => 'comment_author',       :name => 'comment[author]'       } }
    assert_tag :tag => 'form',     :descendant => {                                                                                  
               :tag => 'input',    :attributes => { :type => 'text', :id => 'comment_author_url',   :name => 'comment[author_url]'   } }
    assert_tag :tag => 'form',     :descendant => {                                                                                  
               :tag => 'input',    :attributes => { :type => 'text', :id => 'comment_author_email', :name => 'comment[author_email]' } }
    assert_tag :tag => 'form',     :descendant => { 
               :tag => 'textarea', :attributes => {                  :id => 'comment_body',         :name => 'comment[body]'  } }
  end

  def test_should_show_monthly_entries
    date = Time.now.utc - 4.days
    dispatch "archives/#{date.year}/#{date.month}"
    assert_models_equal [contents(:welcome), contents(:another)], assigns(:articles)
  end
  
  protected
    def dispatch(path = '', options = {})
      get :dispatch, options.merge(:path => path.split('/'))
    end

    def assert_preferred_template(expected)
      assert_equal "#{expected}.liquid", assigns(:site).recent_preferred_template.basename.to_s
    end
    
    def assert_layout_template(expected)
      assert_equal "#{expected}.liquid", assigns(:site).recent_layout_template.basename.to_s
    end
    
    def assert_template_type(expected)
      assert_equal expected, assigns(:site).recent_template_type
    end
    
    def assert_dispatch_action(expected)
      assert_equal expected, assigns(:dispatch_action), "Dispatch action didn't match: #{assigns(:dispatch_path).inspect}"
    end
end
