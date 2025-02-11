# frozen_string_literal: true

module EE
  module Search
    module Filter
      extend ::Gitlab::Utils::Override

      private

      override :filters
      def filters
        super.merge(
          language: params[:language],
          label_name: params[:label_name],
          source_branch: params[:source_branch],
          not_source_branch: params[:not_source_branch],
          target_branch: params[:target_branch],
          not_target_branch: params[:not_target_branch],
          author_username: params[:author_username],
          not_author_username: params[:not_author_username],
          fields: params[:fields],
          hybrid_similarity: params[:hybrid_similarity]&.to_f,
          hybrid_boost: params[:hybrid_boost]&.to_f,
          num_context_lines: params[:num_context_lines]&.to_i,
          type: params[:type]
        )
      end
    end
  end
end
