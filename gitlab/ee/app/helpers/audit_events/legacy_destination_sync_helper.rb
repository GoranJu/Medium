# frozen_string_literal: true

module AuditEvents
  module LegacyDestinationSyncHelper
    include Gitlab::Utils::StrongMemoize

    STREAMING_TOKEN_HEADER_KEY = 'X-Gitlab-Event-Streaming-Token'

    def create_stream_destination(legacy_destination_model:, category:, is_instance:)
      return unless legacy_destination_sync_enabled?(legacy_destination_model, is_instance)

      model_class = if is_instance
                      AuditEvents::Instance::ExternalStreamingDestination
                    else
                      AuditEvents::Group::ExternalStreamingDestination
                    end

      ApplicationRecord.transaction do
        destination = model_class.new(
          name: legacy_destination_model.name,
          category: category,
          config: build_streaming_config(legacy_destination_model, category),
          secret_token: secret_token(legacy_destination_model, category),
          legacy_destination_ref: legacy_destination_model.id
        )
        destination.group = legacy_destination_model.group unless is_instance

        destination.save!

        copy_event_type_filters(legacy_destination_model, destination)
        copy_namespace_filter(legacy_destination_model, destination)

        legacy_destination_model.update!(stream_destination_id: destination.id)
        destination
      end

    rescue ActiveRecord::RecordInvalid, StandardError => e
      Gitlab::ErrorTracking.track_exception(e, audit_event_destination_model: legacy_destination_model.class.name)
      nil
    end

    def update_stream_destination(legacy_destination_model:)
      is_instance = !legacy_destination_model.respond_to?(:group)
      return unless legacy_destination_sync_enabled?(legacy_destination_model, is_instance)

      stream_destination = legacy_destination_model.stream_destination

      return if stream_destination.nil? || stream_destination.legacy_destination_ref != legacy_destination_model.id

      category = stream_destination.category.to_sym

      ApplicationRecord.transaction do
        stream_destination.update!(
          name: legacy_destination_model.name,
          category: category,
          config: build_streaming_config(legacy_destination_model, category),
          secret_token: secret_token(legacy_destination_model, category)
        )

        if stream_destination.respond_to?(:event_type_filters)
          copy_event_type_filters(legacy_destination_model, stream_destination)
        end

        if stream_destination.respond_to?(:namespace_filters)
          copy_namespace_filter(legacy_destination_model, stream_destination)
        end

        stream_destination
      end
    rescue ActiveRecord::RecordInvalid, StandardError => e
      Gitlab::ErrorTracking.track_exception(e, audit_event_destination_model: legacy_destination_model.class.name)
      nil
    end

    private

    def legacy_destination_sync_enabled?(legacy_destination_model, is_instance)
      Feature.enabled?(:audit_events_external_destination_streamer_consolidation_refactor,
        is_instance ? :instance : legacy_destination_model.group)
    end

    def audit_event_namespace(destination)
      destination.instance_level? ? 'AuditEvents::Instance' : 'AuditEvents::Group'
    end

    def copy_event_type_filters(source, destination)
      return unless source.respond_to?(:event_type_filters)

      filter_class = "#{audit_event_namespace(destination)}::EventTypeFilter".constantize
      filter_class.delete_by(external_streaming_destination_id: destination.id)

      timestamp = Time.current

      attributes = source.event_type_filters.map do |filter|
        base_attributes = {
          audit_event_type: filter.audit_event_type,
          external_streaming_destination_id: destination.id,
          created_at: timestamp,
          updated_at: timestamp
        }

        base_attributes[:namespace_id] = destination.group_id unless destination.instance_level?
        base_attributes
      end

      filter_class.insert_all!(attributes) if attributes.any?
    end

    def copy_namespace_filter(source, destination)
      return unless source.respond_to?(:namespace_filter)
      return unless source.namespace_filter

      filter_class = "#{audit_event_namespace(destination)}::NamespaceFilter".constantize
      filter_class.delete_by(external_streaming_destination_id: destination.id)

      filter_class.create!(
        namespace_id: source.namespace_filter.namespace_id,
        external_streaming_destination_id: destination.id
      )
    end

    def build_streaming_config(legacy_destination_model, category)
      case category
      when :http
        {
          'url' => legacy_destination_model.destination_url,
          'headers' => build_headers_config(legacy_destination_model)
        }
      when :aws
        {
          'accessKeyXid' => legacy_destination_model.access_key_xid,
          'bucketName' => legacy_destination_model.bucket_name,
          'awsRegion' => legacy_destination_model.aws_region
        }
      when :gcp
        {
          'googleProjectIdName' => legacy_destination_model.google_project_id_name,
          'logIdName' => legacy_destination_model.log_id_name || 'audit-events',
          'clientEmail' => legacy_destination_model.client_email
        }
      end
    end

    def build_headers_config(legacy_destination_model)
      base_headers = {
        STREAMING_TOKEN_HEADER_KEY => {
          'value' => legacy_destination_model.verification_token,
          'active' => true
        }
      }

      return base_headers unless legacy_destination_model.respond_to?(:headers)

      headers = legacy_destination_model.headers

      headers.active.each_with_object(base_headers) do |header, hash|
        hash[header.key] = {
          'value' => header.value,
          'active' => header.active
        }
      end
    end

    def secret_token(model, category)
      case category
      when :http then model.verification_token
      when :aws then model.secret_access_key
      when :gcp then model.private_key
      end
    end
  end
end
