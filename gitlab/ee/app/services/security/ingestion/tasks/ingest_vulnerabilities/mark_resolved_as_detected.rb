# frozen_string_literal: true

module Security
  module Ingestion
    module Tasks
      class IngestVulnerabilities
        class MarkResolvedAsDetected < AbstractTask
          include Gitlab::Utils::StrongMemoize

          def execute
            return if redetected_vulnerability_ids.blank?

            mark_as_resolved

            finding_maps
          end

          private

          def mark_as_resolved
            Gitlab::Database::SecApplicationRecord.transaction do
              create_state_transitions
              update_vulnerability_records
            end

            set_transitioned_to_detected
          end

          def redetected_vulnerability_ids
            strong_memoize(:redetected_vulnerability_ids) do
              ::Vulnerability.resolved.id_in(vulnerability_ids).pluck_primary_key
            end
          end

          def update_vulnerability_records
            ::Vulnerability.id_in(redetected_vulnerability_ids)
                           .update_all(state: :detected, resolved_at: nil)
          end

          def create_state_transitions
            ::Vulnerabilities::StateTransition.bulk_insert!(state_transitions)
          end

          def state_transitions
            current_time = Time.now.utc

            redetected_vulnerability_ids.map do |vulnerability_id|
              ::Vulnerabilities::StateTransition.new(
                vulnerability_id: vulnerability_id,
                from_state: :resolved,
                to_state: :detected,
                created_at: current_time,
                updated_at: current_time
              )
            end
          end

          def set_transitioned_to_detected
            updated_finding_maps.each { |finding_map| finding_map.transitioned_to_detected = true }
          end

          def updated_finding_maps
            finding_maps.select { |finding_map| redetected_vulnerability_ids.include?(finding_map.vulnerability_id) }
          end

          def vulnerability_ids
            finding_maps.map(&:vulnerability_id)
          end
        end
      end
    end
  end
end
