# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'test_helper'

module Awesome
  module Provider; class MyAwesome < ::ComputeResource; end; end
  def self.register_smart_proxy(name, options = {}); end
end
module Awesome; class FakeFacet; end; end

class PluginTest < ActiveSupport::TestCase
  module MyMod
    def my_helper
      'my_helper'
    end

    private

    def private_helper
      'private_helper'
    end
  end

  def setup
    @klass = Foreman::Plugin
    # In case some real plugins are installed
    @klass.clear
  end

  def teardown
    @klass.clear
  end

  def test_register
    @klass.register :foo do
      name 'Foo plugin'
      url 'http://example.net/plugins/foo'
      author 'John Smith'
      author_url 'http://example.net/jsmith'
      description 'This is a test plugin'
      version '0.0.1'
      path '/some/path/on/disk'
    end

    assert_equal 1, @klass.all.size

    plugin = @klass.find('foo')
    assert plugin.is_a?(Foreman::Plugin)
    assert_equal :foo, plugin.id
    assert_equal 'Foo plugin', plugin.name
    assert_equal 'http://example.net/plugins/foo', plugin.url
    assert_equal 'John Smith', plugin.author
    assert_equal 'http://example.net/jsmith', plugin.author_url
    assert_equal 'This is a test plugin', plugin.description
    assert_equal '0.0.1', plugin.version
    assert_equal '/some/path/on/disk', plugin.path
  end

  def test_installed
    @klass.register(:foo) {}
    assert_equal true, @klass.installed?(:foo)
    assert_equal false, @klass.installed?(:bar)
  end

  def test_menu
    url_hash = {:controller=>'hosts', :action=>'index'}
    assert_difference 'Menu::Manager.items(:project_menu).size' do
      @klass.register :foo do
        menu :project_menu, :foo_menu_item, :url_hash=>url_hash, :caption => 'Foo'
      end
    end
    menu_item = Menu::Manager.items(:project_menu).detect {|i| i.name == :foo_menu_item}
    assert_not_nil menu_item
    assert_equal 'Foo', menu_item.caption
    assert_equal url_hash, menu_item.url_hash
  end

  def test_delete_menu_item
    Menu::Manager.map(:project_menu).item(:foo_menu_item, :caption => 'Foo')
    assert_difference 'Menu::Manager.items(:project_menu).size', -1 do
      @klass.register :foo do
        delete_menu_item :project_menu, :foo_menu_item
      end
    end
    assert_nil Menu::Manager.items(:project_menu).detect {|i| i.name == :foo_menu_item}
  end

  def test_requires_foreman_2_part
    plugin = Foreman::Plugin.register(:foo) {}
    SETTINGS[:version].stubs(:notag).returns('2.1')

    # Specific version without hash
    assert plugin.requires_foreman('= 2.1')
    assert plugin.requires_foreman('~> 2.1')
    assert_raise Foreman::PluginRequirementError do
      plugin.requires_foreman('2.2')
    end
    assert_raise Foreman::PluginRequirementError do
      plugin.requires_foreman('3')
    end

    # Specific version
    assert plugin.requires_foreman('= 2.1')
    assert plugin.requires_foreman('~> 2.1')
    assert_raise Foreman::PluginRequirementError do
      plugin.requires_foreman('= 2.2')
    end
    assert_raise Foreman::PluginRequirementError do
      plugin.requires_foreman('= 2.0')
    end
    assert_raise Foreman::PluginRequirementError do
      plugin.requires_foreman('= 3')
    end

    # Version or higher
    assert plugin.requires_foreman('>= 0.1')
    assert plugin.requires_foreman('>= 2.1')
    assert_raise Foreman::PluginRequirementError do
      plugin.requires_foreman('>= 2.2')
    end
    assert_raise Foreman::PluginRequirementError do
      plugin.requires_foreman('>= 3')
    end
  end

  def test_requires_foreman_3_part
    plugin = Foreman::Plugin.register(:foo) {}
    SETTINGS[:version].stubs(:notag).returns('2.1.3')

    # Specific version without hash
    assert plugin.requires_foreman('= 2.1.3')
    assert plugin.requires_foreman('~> 2.1.0')
    assert_raise Foreman::PluginRequirementError do
      plugin.requires_foreman('2.1.4')
    end
    assert_raise Foreman::PluginRequirementError do
      plugin.requires_foreman('2.2')
    end

    # Specific version
    assert plugin.requires_foreman('= 2.1.3')
    assert plugin.requires_foreman('~> 2.1')
    assert_raise Foreman::PluginRequirementError do
      plugin.requires_foreman('= 2.2.0')
    end
    assert_raise Foreman::PluginRequirementError do
      plugin.requires_foreman('= 2.1.4')
    end
    assert_raise Foreman::PluginRequirementError do
      plugin.requires_foreman('= 2.2')
    end

    # Version or higher
    assert plugin.requires_foreman('>= 0.1.0')
    assert plugin.requires_foreman('>= 2.1.3')
    assert plugin.requires_foreman('>= 2.1')
    assert_raise Foreman::PluginRequirementError do
      plugin.requires_foreman('>= 2.2.0')
    end
    assert_raise Foreman::PluginRequirementError do
      plugin.requires_foreman('>= 2.2')
    end
  end

  def test_requires_foreman_plugin
    test = self
    other_version = '0.5.0'
    @klass.register :other do
      name 'Other'
      version other_version
    end
    @klass.register :foo do
      test.assert requires_foreman_plugin(:other, '>= 0.1.0')
      test.assert requires_foreman_plugin(:other, other_version)
      test.assert_raise Foreman::PluginRequirementError do
        requires_foreman_plugin(:other, '>= 99.0.0')
      end
      test.assert_raise Foreman::PluginRequirementError do
        requires_foreman_plugin(:other, '= 99.0.0')
      end

      # Missing plugin
      test.assert_raise Foreman::PluginNotFound do
        requires_foreman_plugin(:missing, '>= 0.1.0')
      end
      test.assert_raise Foreman::PluginNotFound do
        requires_foreman_plugin(:missing, '0.1.0')
      end
      test.assert_raise Foreman::PluginNotFound do
        requires_foreman_plugin(:missing, '= 0.1.0')
      end
    end
  end

  def test_register_allowed_template_helpers_and_variables
    refute_includes Foreman::Renderer::ALLOWED_HELPERS, :my_helper
    refute_includes Foreman::Renderer::ALLOWED_VARIABLES, :my_variable

    @klass.register :foo do
      allowed_template_helpers :my_helper
      allowed_template_variables :my_variable
    end
    # simulate application start
    @klass.find(:foo).to_prepare_callbacks.each(&:call)

    assert_includes Foreman::Renderer::ALLOWED_HELPERS, :my_helper
    assert_includes Foreman::Renderer::ALLOWED_VARIABLES, :my_variable
  ensure
    Foreman::Renderer::ALLOWED_HELPERS.delete(:my_helper)
    Foreman::Renderer::ALLOWED_HELPERS.delete(:my_variable)
  end

  def test_extend_rendering_helpers
    refute Foreman::Renderer.public_instance_methods.include?(:my_helper)
    refute_includes Foreman::Renderer::ALLOWED_HELPERS, :my_helper
    refute ::TemplatesController.public_instance_methods.include?(:my_helper)

    @klass.register(:foo) do
      extend_template_helpers(MyMod)
    end
    # simulate application start
    @klass.find(:foo).to_prepare_callbacks.each(&:call)

    assert UnattendedHelper.public_instance_methods.include?(:my_helper)
    refute UnattendedHelper.public_instance_methods.include?(:private_helper)
    assert_includes Foreman::Renderer::ALLOWED_HELPERS, :my_helper
    refute_includes Foreman::Renderer::ALLOWED_HELPERS, :private_helper
    assert ::TemplatesController.public_instance_methods.include?(:my_helper)
    refute ::TemplatesController.public_instance_methods.include?(:private_helper)
  ensure
    Foreman::Renderer::ALLOWED_HELPERS.delete(:my_helper)
    Foreman::Renderer::ALLOWED_HELPERS.delete(:my_variable)
  end

  def test_add_compute_resource
    Foreman::Plugin.register :awesome_compute do
      name 'Awesome compute'
      compute_resource Awesome::Provider::MyAwesome
    end
    assert ComputeResource.providers.keys.must_include 'MyAwesome'
    assert ComputeResource.providers.values.must_include 'Awesome::Provider::MyAwesome'
    assert_equal ComputeResource.provider_class('MyAwesome'), 'Awesome::Provider::MyAwesome'
    assert ComputeResource.registered_providers.keys.must_include 'MyAwesome'
    assert ComputeResource.registered_providers.values.must_include 'Awesome::Provider::MyAwesome'
  end

  def test_invalid_compute_resource
    e = assert_raise(Foreman::Exception) do
      Foreman::Plugin.register :awesome_compute do
        name 'Awesome compute'
        compute_resource String
      end
    end
    assert_match /wrong type supplied/, e.message
  end

  def test_add_search_path_override
    Foreman::Plugin.register :filter_helpers do
      search_path_override("TestEngine") { |resource| "test_engine/another_search_path" }
    end
    assert FiltersHelperOverrides.can_override?("TestEngine::TestResource")
  end

  def test_can_merge_tests_to_skip_arrays
    @klass.register :foo do
      tests_to_skip "FooTest" => [ "test1", "test2" ]
    end
    @klass.register :bar do
      tests_to_skip "FooTest" => [ "test3", "test4" ]
    end
    assert_equal [ "test1", "test2", "test3", "test4" ], @klass.tests_to_skip["FooTest"]
  end

  def test_configure_logging
    Foreman::Plugin::Logging.any_instance.expects(:configure).with(nil)
    @klass.register(:foo) {}

    assert Foreman::Plugin.find(:foo).logging
  end

  def test_logger
    Foreman::Plugin::Logging.any_instance.expects(:configure).with(nil)
    @klass.register(:foo) {}
    plugin = Foreman::Plugin.find(:foo)

    plugin.logging.expects(:add_logger).with(:test_logger, {:enabled => true})
    plugin.logger(:test_logger, {:enabled => true})
  end

  def test_register_custom_status
    status = Struct.new(:status)
    @klass.register :foo do
      register_custom_status(status)
    end
    # simulate application start
    @klass.find(:foo).to_prepare_callbacks.each(&:call)
    assert_include HostStatus.status_registry, status
    HostStatus.status_registry.delete status
  end

  def test_add_provision_method
    Foreman::Plugin.register :awesome_provision do
      name 'Awesome provision'
      provision_method 'awesome', 'Awesomeness Based'
    end
    assert_equal 'Awesomeness Based', Host::Managed.provision_methods['awesome']
  end

  def test_extend_page
    Foreman::Plugin.register(:foo) do
      extend_page("tests/show") do |context|
        context.add_pagelet :main_tabs, :name => "My Tab", :partial => "partial"
      end
    end

    assert_equal 1, ::Pagelets::Manager.pagelets_at("tests/show", :main_tabs).count
    assert_equal "My Tab", ::Pagelets::Manager.pagelets_at("tests/show", :main_tabs).first.name
  end

  def test_register_facet
    Facets.stubs(:configuration).returns({})

    Foreman::Plugin.register :awesome_facet do
      name 'Awesome facet'
      register_facet(Awesome::FakeFacet, :fake_facet) do
        api_view :list => 'api/v2/awesome/index', :single => 'api/v2/awesome/show'
      end
    end

    assert Facets.registered_facets[:fake_facet]

    Host::Managed.cloned_parameters[:include].delete(:fake_facet)
  end

  def test_add_template_label
    kind = FactoryGirl.build(:template_kind)
    Foreman::Plugin.register :test_template_kind do
      name 'Test template kind'
      template_labels kind.name => 'Test plugin template kind'
    end
    assert_equal 'Test plugin template kind', kind.to_s
  end

  def test_add_parameter_filter
    Foreman::Plugin.register :test_parameter_filter do
      name 'Parameter filter test'
      parameter_filter Domain, :foo, :bar => [], :ui => true
    end
    assert_equal([], Foreman::Plugin.find(:test_parameter_filter).parameter_filters(User))
    assert_equal([[:foo, :bar => [], :ui => true]], Foreman::Plugin.find(:test_parameter_filter).parameter_filters(Domain))
    assert_equal([[:foo, :bar => [], :ui => true]], Foreman::Plugin.find(:test_parameter_filter).parameter_filters('Domain'))
  end

  def test_add_parameter_filter_block
    Foreman::Plugin.register :test_parameter_filter do
      name 'Parameter filter test'
      parameter_filter(Domain) { |ctx| ctx.permit(:foo) }
    end
    assert_kind_of Proc, Foreman::Plugin.find(:test_parameter_filter).parameter_filters(Domain).first.first
  end

  def test_add_smart_proxy_for
    Foreman::Plugin.register :test_smart_proxy do
      name 'Smart Proxy test'
      smart_proxy_for Awesome, :foo, :feature => 'Foo'
    end
    assert_equal({}, Foreman::Plugin.find(:test_smart_proxy).smart_proxies(User))
    assert_equal({:foo => {:feature => 'Foo'}}, Foreman::Plugin.find(:test_smart_proxy).smart_proxies(Awesome))
  end

  context "adding permissions" do
    teardown do
      permission = Foreman::AccessControl.permission(:test_permission)
      Foreman::AccessControl.remove_permission(permission) if permission
    end

    def test_add_permission
      Foreman::Plugin.register :test_permission do
        name 'Permission test'
        security_block :test_permission do
          permission :test_permission, {:controller_name => [:test]}
        end
      end
      assert_includes Foreman::Plugin.find(:test_permission).permissions.keys, :test_permission
      ac_permission = Foreman::AccessControl.permission(:test_permission)
      assert ac_permission, ":test_permission is not registered in Foreman::AccessControl"
      assert_equal ['controller_name/test'], ac_permission.actions
    end

    def test_add_role
      Foreman::Plugin.register :test_role do
        name 'Role test'
        security_block :test_permission do
          permission :test_permission, {:controller_name => [:test]}
        end
        role 'Test role', [:test_permission]
      end
      assert_equal({'Test role' => [:test_permission]}, Foreman::Plugin.find(:test_role).default_roles)
    end
  end
end
