# frozen_string_literal: true

module ProductAnalytics
  class Panel
    attr_reader :title, :grid_attributes, :visualization, :project, :query_overrides

    def self.from_data(panel_yaml, project)
      return if panel_yaml.nil?

      panel_yaml.map do |panel|
        new(
          title: panel['title'],
          project: project,
          grid_attributes: panel['gridAttributes'],
          query_overrides: panel['queryOverrides'],
          visualization_config: panel['visualization']
        )
      end
    end

    def initialize(title:, grid_attributes:, visualization_config:, project:, query_overrides:)
      @title = title
      @project = project
      @grid_attributes = grid_attributes
      @query_overrides = query_overrides

      return if visualization_config.blank?

      @visualization = if visualization_config.is_a?(String)
                         ::ProductAnalytics::Visualization.from_file(filename: visualization_config, project: project)
                       else
                         ::ProductAnalytics::Visualization.from_data(data: visualization_config)
                       end
    end
  end
end
