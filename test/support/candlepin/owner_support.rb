require 'katello_test_helper'

# rubocop:disable Naming/AccessorMethodName
module Katello
  module CandlepinOwnerSupport
    @organization = nil

    def self.organization_id
      @organization.id
    end

    class << self
      attr_reader :organization
    end

    def self.set_owner(org)
      # TODO: this tests should move to actions tests once we
      # have more actions in Dynflow. For now just peform the
      # things that system.set_pulp_consumer did before.
      destroy_organization(org) if owner_exists?(org.label)
      ForemanTasks.sync_task(::Actions::Candlepin::Owner::Create, name: org.name, label: org.label)
    end

    def self.owner_exists?(label)
      Katello::Resources::Candlepin::Owner.find(label)
    rescue RestClient::ResourceNotFound
      false
    end

    def set_owner(org)
      self.class.set_owner(org)
    end

    def self.create_organization(name, label)
      @organization = Organization.new
      @organization.name = name
      @organization.label = label
      @organization.description = 'New Organization'
      Organization.stubs(:disable_auto_reindex!).returns

      set_owner(@organization)
      @organization
    rescue => e
      puts e
      @organization
    end

    def self.import_manifest(owner_label, path_to_file)
      path = "/candlepin/owners/#{owner_label}/imports?force=SIGNATURE_CONFLICT&force=MANIFEST_SAME"
      client = ::Katello::Resources::Candlepin::CandlepinResource.rest_client(Net::HTTP::Post, :post, path)
      body = {:import => File.new(path_to_file, 'rb')}
      client.post body, {:accept => :json}.merge(User.cp_oauth_header)
    end

    def self.destroy_organization(organization)
      Resources::Candlepin::Owner.destroy(organization.label)
    rescue RestClient::ResourceNotFound => e
      puts e
    end
  end
end
