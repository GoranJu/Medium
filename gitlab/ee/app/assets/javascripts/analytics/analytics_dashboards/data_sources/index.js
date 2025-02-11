/**
 * Imports an analytics dashboard datasource
 *
 * A datasource is a file that exports a single default `fetch` function with the following signature:
 *
 * @param {Object} options - The options object
 * @param {string} options.title - The title of the project
 * @param {number} options.projectId - The ID of the project
 * @param {string} options.namespace - // the namespace full path
 * @param {boolean} options.isProject - If `true` this dashboard is project-level, otherwise group-level
 * @param {Object} options.query - The query object for fetching data
 * @param {Object} [options.queryOverrides={}] - Optional overrides for the base query.  Refert to `QueryOverrides` in `ee/app/validators/json_schemas/analytics_visualization.json`
 *
 * @param {string} options.visualizationType - The type of visualization to render (line chart, table, etc.). Refer to `AnalyticsVisualization.type` in `ee/app/validators/json_schemas/analytics_visualization.json`
 * @param {Object} options.visualizationOptions - Additional options for customizing the visualization Refer to `Options` in `ee/app/validators/json_schemas/analytics_visualization.json`
 * @param {Object} [options.filters={}] - Optional filters to apply to the query (date range, anon users, etc.). Refer to `DashboardFilters` in `ee/app/validators/json_schemas/analytics_dashboard.json`
 * @param {Function} [options.onRequestDelayed=()=>{}] - Callback function when request is delayed. It can trigger a loading spinner in the panel
 * @param {Function} [options.setAlerts=()=>{}] - Callback function to set alerts
 * @param {Function} [options.setVisualizationOverrides=()=>{}] - Callback function to set visualization options before render but after the data fetch, allowing us to include fetched data in the visualization options
 *
 * @returns {Promise<Array|Object>} The formatted data for the specified visualization type
 *
 * @throws {Error} If the API request fails
 *
 * export default async function fetch(options);
 *
 */

export default {
  cube_analytics: () => import('./cube_analytics'),
  value_stream: () => import('./value_stream'),
  usage_overview: () => import('./usage_overview'),
  dora_metrics_over_time: () => import('./dora_metrics_over_time'),
  dora_metrics_by_project: () => import('./dora_metrics_by_project'),
  ai_impact_over_time: () => import('./ai_impact_over_time'),
  contributions: () => import('./contributions'),
};
