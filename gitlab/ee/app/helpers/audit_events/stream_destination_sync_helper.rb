# frozen_string_literal: true

module AuditEvents
  module StreamDestinationSyncHelper
    include Gitlab::Utils::StrongMemoize

    CreateError = Class.new(StandardError)
    UpdateError = Class.new(StandardError)

    CATEGORY_MAPPING = {
      'http' => 'ExternalAuditEventDestination',
      'aws' => 'AmazonS3Configuration',
      'gcp' => 'GoogleCloudLoggingConfiguration'
    }.freeze

    def create_legacy_destination(stream_destination_model)
      return unless stream_destination_sync_enabled?(stream_destination_model)

      model_class = legacy_class_for(stream_destination_model)

      ApplicationRecord.transaction do
        destination = model_class.new(
          name: stream_destination_model.name,
          stream_destination_id: stream_destination_model.id,
          **extract_legacy_attributes(stream_destination_model)
        )
        destination.namespace_id = stream_destination_model.group_id if destination.respond_to?(:group)

        destination.save!
        copy_legacy_event_type_filters(stream_destination_model, destination)
        copy_legacy_namespace_filters(stream_destination_model, destination) if stream_destination_model.http?

        stream_destination_model.update_column(:legacy_destination_ref, destination.id)

        destination
      end
    rescue ActiveRecord::RecordInvalid, CreateError => e
      Gitlab::ErrorTracking.track_exception(e, audit_event_destination_model: stream_destination_model.class.name)
      nil
    end

    def update_legacy_destination(stream_destination_model)
      return unless stream_destination_sync_enabled?(stream_destination_model)

      destination = stream_destination_model.legacy_destination

      return if destination.nil? || destination.stream_destination_id != stream_destination_model.id

      ApplicationRecord.transaction do
        destination.update!(
          name: stream_destination_model.name,
          **extract_legacy_attributes(stream_destination_model)
        )
        destination
      end
    rescue ActiveRecord::RecordInvalid, UpdateError => e
      Gitlab::ErrorTracking.track_exception(e, audit_event_destination_model: stream_destination_model.class.name)
      nil
    end

    private

    def stream_destination_sync_enabled?(stream_destination_model)
      Feature.enabled?(:audit_events_external_destination_streamer_consolidation_refactor,
        stream_destination_model.respond_to?(:group) ? stream_destination_model.group : :instance)
    end

    def legacy_class_for(model)
      strong_memoize(:legacy_class) do
        base = model.instance_level? ? 'AuditEvents::Instance::' : 'AuditEvents::'
        base = 'AuditEvents::Instance' if model.instance_level? && model.category == 'http'

        "#{base}#{CATEGORY_MAPPING[model.category]}".safe_constantize
      end
    end

    def extract_legacy_attributes(stream_destination_model)
      case stream_destination_model.category
      when 'http'
        {
          destination_url: stream_destination_model.config['url'],
          verification_token: stream_destination_model.secret_token
        }
      when 'aws'
        {
          bucket_name: stream_destination_model.config['bucketName'],
          aws_region: stream_destination_model.config['awsRegion'],
          access_key_xid: stream_destination_model.config['accessKeyXid'],
          secret_access_key: stream_destination_model.secret_token
        }
      when 'gcp'
        {
          google_project_id_name: stream_destination_model.config['googleProjectIdName'],
          log_id_name: stream_destination_model.config['logIdName'],
          client_email: stream_destination_model.config['clientEmail'],
          private_key: stream_destination_model.secret_token
        }
      end
    end

    def copy_legacy_event_type_filters(source, destination)
      return unless source.respond_to?(:event_type_filters)

      source.event_type_filters.find_each do |filter|
        filter_class = if destination.instance_level?
                         AuditEvents::Streaming::InstanceEventTypeFilter
                       else
                         AuditEvents::Streaming::EventTypeFilter
                       end

        attributes = {
          audit_event_type: filter.audit_event_type
        }

        if destination.instance_level?
          attributes[:instance_external_audit_event_destination] = destination
        else
          attributes[:external_audit_event_destination] = destination
        end

        filter_class.create!(attributes)
      end
    end

    def copy_legacy_namespace_filters(source, destination)
      return unless source.namespace_filters.any?

      filter_class = if destination.instance_level?
                       AuditEvents::Streaming::HTTP::Instance::NamespaceFilter
                     else
                       AuditEvents::Streaming::HTTP::NamespaceFilter
                     end

      source.namespace_filters.first.tap do |filter|
        column_name = if destination.instance_level?
                        'audit_events_instance_external_audit_event_destination_id'
                      else
                        'external_audit_event_destination_id'
                      end

        filter_class.create!(
          namespace: filter.namespace,
          column_name => destination.id
        )
      end
    end
  end
end
