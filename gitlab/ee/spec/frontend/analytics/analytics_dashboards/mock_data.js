import { TEST_HOST } from 'spec/test_constants';
import { getUniquePanelId } from '~/vue_shared/components/customizable_dashboard/utils';

export const TEST_TRACKING_KEY = 'gid://gitlab/Project/2';

export const TEST_COLLECTOR_HOST = TEST_HOST;

export const TEST_ROUTER_BACK_HREF = 'go-back';

export const TEST_CUSTOM_DASHBOARDS_GROUP = {
  fullPath: 'test-namespace',
  id: 12,
  name: 'test-dashboards-namespace',
};

export const TEST_CUSTOM_DASHBOARDS_PROJECT = {
  fullPath: 'test/test-dashboards',
  id: 123,
  name: 'test-dashboards',
  defaultBranch: 'some-branch',
};

export const getGraphQLDashboard = (options = {}, withPanels = true) => {
  const newDashboard = {
    slug: '',
    title: '',
    userDefined: false,
    status: null,
    description: 'Understand your audience',
    __typename: 'CustomizableDashboard',
    errors: [],
    filters: {},
    ...options,
  };

  if (withPanels) {
    return {
      ...newDashboard,
      panels: {
        nodes: [
          {
            title: 'Daily Active Users',
            gridAttributes: {
              yPos: 1,
              xPos: 0,
              width: 6,
              height: 5,
            },
            queryOverrides: {
              limit: 200,
            },
            visualization: {
              slug: 'line_chart',
              type: 'LineChart',
              options: {
                xAxis: {
                  name: 'Time',
                  type: 'time',
                },
                yAxis: {
                  name: 'Counts',
                  type: 'time',
                },
              },
              data: {
                type: 'cube_analytics',
                query: {
                  measures: ['TrackedEvents.uniqueUsersCount'],
                  timeDimensions: [
                    {
                      dimension: 'TrackedEvents.derivedTstamp',
                      granularity: 'day',
                    },
                  ],
                  limit: 100,
                  timezone: 'UTC',
                  filters: [],
                  dimensions: [],
                },
              },
              errors: null,
              __typename: 'CustomizableDashboardVisualization',
            },
            __typename: 'CustomizableDashboardPanel',
          },
        ],
        __typename: 'CustomizableDashboardPanelConnection',
      },
    };
  }

  return newDashboard;
};

export const TEST_DASHBOARD_GRAPHQL_404_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      customizableDashboards: {
        nodes: [],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Project',
    },
  },
};

export const TEST_AUDIENCE_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      customizableDashboards: {
        nodes: [
          getGraphQLDashboard(
            {
              slug: 'audience',
              title: 'Audience',
            },
            true,
          ),
        ],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Project',
    },
  },
};

export const TEST_CUSTOM_VSD_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      customizableDashboards: {
        nodes: [
          getGraphQLDashboard({
            slug: 'value_streams_dashboard',
            title: 'Value Streams Dashboard',
            userDefined: false,
          }),
        ],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Project',
    },
  },
};

export const TEST_CUSTOM_GROUP_VSD_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE = {
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      customizableDashboards: {
        nodes: [
          getGraphQLDashboard(
            {
              slug: 'value_streams_dashboard',
              title: 'Value Streams Dashboard',
              userDefined: false,
              panels: [],
            },
            false,
          ),
        ],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Group',
    },
  },
};

export const TEST_AI_IMPACT_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      customizableDashboards: {
        nodes: [
          getGraphQLDashboard({
            slug: 'ai_impact',
            title: 'AI impact analytics',
            userDefined: false,
          }),
        ],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Project',
    },
  },
};

export const TEST_DASHBOARD_GRAPHQL_EMPTY_SUCCESS_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      customizableDashboards: {
        nodes: [],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Project',
    },
  },
};

const mockUsageOverviewPanel = {
  __typename: 'CustomizableDashboardPanel',
  title: 'Usage overview',
  gridAttributes: { yPos: 0, xPos: 0, width: 12, height: 1 },
  queryOverrides: null,
  visualization: {
    __typename: 'CustomizableDashboardVisualization',
    slug: 'usage_overview',
    type: 'UsageOverview',
    options: {},
    data: {
      type: 'usage_overview',
      query: { include: ['groups', 'projects', 'issues', 'merge_requests', 'pipelines'] },
    },
    errors: null,
  },
};

export const TEST_DASHBOARD_WITH_USAGE_OVERVIEW_GRAPHQL_SUCCESS_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      customizableDashboards: {
        nodes: [
          getGraphQLDashboard(
            {
              slug: 'value_streams_dashboard',
              title: 'Value Streams Dashboard',
              userDefined: false,
              panels: {
                nodes: [mockUsageOverviewPanel],
                __typename: 'CustomizableDashboardPanelConnection',
              },
            },
            false,
          ),
        ],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Project',
    },
  },
};

export const mockInvalidDashboardErrors = [
  'root is missing required keys: version',
  "property '/panels/0' is missing required keys: queryOverrides",
  "property '/panels/0/id' is invalid: error_type=schema",
  "property '/panels/1' is missing required keys: queryOverrides",
  "property '/panels/1/id' is invalid: error_type=schema",
  "property '/panels/2' is missing required keys: queryOverrides",
  "property '/panels/2/id' is invalid: error_type=schema",
];

export const TEST_INVALID_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      customizableDashboards: {
        nodes: [
          getGraphQLDashboard({
            slug: 'custom_dashboard',
            title: 'Custom Dashboard',
            userDefined: true,
            errors: mockInvalidDashboardErrors,
          }),
        ],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Project',
    },
  },
};

export const createDashboardGraphqlSuccessResponse = (dashboardNodes) => ({
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      customizableDashboards: {
        nodes: [dashboardNodes],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Project',
    },
  },
});

export const mockResultSet = {
  seriesNames: () => [
    {
      title: 'pageview, TrackedEvents Count',
      key: 'pageview,TrackedEvents.count',
      yValues: ['pageview', 'TrackedEvents.count'],
    },
  ],
  chartPivot: () => [
    {
      x: '2022-11-09T00:00:00.000',
      xValues: ['2022-11-09T00:00:00.000'],
      'pageview,TrackedEvents.count': 55,
    },
    {
      x: '2022-11-10T00:00:00.000',
      xValues: ['2022-11-10T00:00:00.000'],
      'pageview,TrackedEvents.count': 14,
    },
  ],
  tableColumns: () => [
    {
      key: 'TrackedEvents.utcTime.day',
      title: 'TrackedEvents Utc Time',
      shortTitle: 'Utc Time',
      type: 'time',
      dataIndex: 'TrackedEvents.utcTime.day',
    },
    {
      key: 'TrackedEvents.eventType',
      title: 'TrackedEvents Event Type',
      shortTitle: 'Event Type',
      type: 'string',
      dataIndex: 'TrackedEvents.eventType',
    },
    {
      key: 'TrackedEvents.count',
      type: 'number',
      dataIndex: 'TrackedEvents.count',
      title: 'TrackedEvents Count',
      shortTitle: 'Count',
    },
  ],
  tablePivot: () => [
    {
      'TrackedEvents.utcTime.day': '2022-11-09T00:00:00.000',
      'TrackedEvents.eventType': 'pageview',
      'TrackedEvents.count': '55',
    },
    {
      'TrackedEvents.utcTime.day': '2022-11-10T00:00:00.000',
      'TrackedEvents.eventType': 'pageview',
      'TrackedEvents.count': '14',
    },
  ],
  rawData: () => [
    {
      'TrackedEvents.userLanguage': 'en-US',
      'TrackedEvents.count': '36',
      'TrackedEvents.url': 'https://example.com/us',
    },
    {
      'TrackedEvents.userLanguage': 'es-ES',
      'TrackedEvents.count': '60',
      'TrackedEvents.url': 'https://example.com/es',
    },
  ],
};

export const mockTableWithLinksResultSet = {
  tableColumns: () => [
    {
      key: 'TrackedEvents.docPath',
      title: 'Tracked Events Doc Path',
      shortTitle: 'Doc Path',
      type: 'string',
      dataIndex: 'TrackedEvents.docPath',
    },
    {
      key: 'TrackedEvents.url',
      title: 'Tracked Events Url',
      shortTitle: 'Url',
      type: 'string',
      dataIndex: 'TrackedEvents.url',
    },
    {
      key: 'TrackedEvents.pageViewsCount',
      type: 'number',
      dataIndex: 'TrackedEvents.pageViewsCount',
      title: 'Tracked Events Page Views Count',
      shortTitle: 'Page Views Count',
    },
  ],
  tablePivot: () => [
    {
      'TrackedEvents.docPath': '/foo',
      'TrackedEvents.url': 'https://example.com/foo',
      'TrackedEvents.pageViewsCount': '1',
    },
  ],
};

export const mockResultSetWithNullValues = {
  rawData: () => [
    {
      'TrackedEvents.userLanguage': null,
      'TrackedEvents.count': null,
      'TrackedEvents.url': null,
    },
  ],
};

export const mockContinueWaitProgressResult = {
  progressResponse: {
    error: 'Continue wait',
  },
};

export const mockFilters = {
  startDate: new Date('2015-01-01'),
  endDate: new Date('2016-01-01'),
};

export const mockMetaData = {
  cubes: [
    {
      name: 'Sessions',
      type: 'cube',
      title: 'Sessions',
      isVisible: true,
      public: true,
      measures: [
        {
          name: 'Sessions.count',
          title: 'Sessions Count',
          shortTitle: 'Count',
          cumulativeTotal: false,
          cumulative: false,
          type: 'number',
          aggType: 'count',
          drillMembers: [],
          drillMembersGrouped: {
            measures: [],
            dimensions: [],
          },
          isVisible: true,
          public: true,
        },
        {
          name: 'Sessions.averagePerUser',
          title: 'Sessions Average Per User',
          shortTitle: 'Average Per User',
          cumulativeTotal: false,
          cumulative: false,
          type: 'number',
          aggType: 'number',
          drillMembers: [],
          drillMembersGrouped: {
            measures: [],
            dimensions: [],
          },
          isVisible: true,
          public: true,
        },
      ],
      dimensions: [
        {
          name: 'Sessions.sessionID',
          title: 'Sessions Session Id',
          type: 'string',
          shortTitle: 'Session Id',
          suggestFilterValues: true,
          isVisible: false,
          public: false,
          primaryKey: true,
        },
        {
          name: 'Sessions.startAt',
          title: 'Sessions Start at',
          type: 'time',
          shortTitle: 'Start at',
          suggestFilterValues: true,
          isVisible: true,
          public: true,
          primaryKey: false,
        },
        {
          name: 'Sessions.endAt',
          title: 'Sessions End at',
          type: 'time',
          shortTitle: 'End at',
          suggestFilterValues: true,
          isVisible: true,
          public: true,
          primaryKey: false,
        },
      ],
      segments: [],
      hierarchies: [],
    },
    {
      name: 'TrackedEvents',
      type: 'cube',
      title: 'Tracked Events',
      isVisible: true,
      public: true,
      measures: [
        {
          name: 'TrackedEvents.pageViewsCount',
          title: 'Tracked Events Page Views Count',
          shortTitle: 'Page Views Count',
          cumulativeTotal: false,
          cumulative: false,
          type: 'number',
          aggType: 'count',
          drillMembers: [],
          drillMembersGrouped: {
            measures: [],
            dimensions: [],
          },
          isVisible: true,
          public: true,
        },
        {
          name: 'TrackedEvents.count',
          title: 'Tracked Events Count',
          shortTitle: 'Count',
          cumulativeTotal: false,
          cumulative: false,
          type: 'number',
          aggType: 'count',
          drillMembers: ['TrackedEvents.eventId', 'TrackedEvents.pageTitle'],
          drillMembersGrouped: {
            measures: [],
            dimensions: ['TrackedEvents.eventId', 'TrackedEvents.pageTitle'],
          },
          isVisible: true,
        },
      ],
      dimensions: [
        {
          name: 'TrackedEvents.pageTitle',
          title: 'Tracked Events Page Title',
          type: 'string',
          shortTitle: 'Page Title',
          suggestFilterValues: true,
          isVisible: true,
          public: true,
          primaryKey: false,
        },
        {
          name: 'TrackedEvents.pageUrl',
          title: 'Tracked Events Page Url',
          type: 'string',
          shortTitle: 'Page Url',
          suggestFilterValues: true,
          isVisible: true,
          public: true,
          primaryKey: false,
        },
        {
          name: 'TrackedEvents.derivedTstamp',
          title: 'Tracked Events Derived Tstamp',
          type: 'time',
          shortTitle: 'Derived Tstamp',
          suggestFilterValues: true,
          isVisible: true,
          public: true,
          primaryKey: false,
        },
      ],
      segments: [
        {
          name: 'TrackedEvents.knownUsers',
          title: 'Tracked Events Known Users',
          shortTitle: 'Known Users',
          isVisible: true,
          public: true,
        },
      ],
      hierarchies: [],
    },
  ],
};

export const mockFilterOptions = {
  availableMeasures: [
    {
      name: 'Sessions.count',
      title: 'Sessions Count',
      shortTitle: 'Count',
      cumulativeTotal: false,
      cumulative: false,
      type: 'number',
      aggType: 'count',
      drillMembers: [],
      drillMembersGrouped: {
        measures: [],
        dimensions: [],
      },
      isVisible: true,
      public: true,
    },
    {
      name: 'Sessions.averagePerUser',
      title: 'Sessions Average Per User',
      shortTitle: 'Average Per User',
      cumulativeTotal: false,
      cumulative: false,
      type: 'number',
      aggType: 'number',
      drillMembers: [],
      drillMembersGrouped: {
        measures: [],
        dimensions: [],
      },
      isVisible: true,
      public: true,
    },
    {
      name: 'TrackedEvents.pageViewsCount',
      title: 'Tracked Events Page Views Count',
      shortTitle: 'Page Views Count',
      cumulativeTotal: false,
      cumulative: false,
      type: 'number',
      aggType: 'count',
      drillMembers: [],
      drillMembersGrouped: {
        measures: [],
        dimensions: [],
      },
      isVisible: true,
      public: true,
    },
    {
      name: 'TrackedEvents.count',
      title: 'Tracked Events Count',
      shortTitle: 'Count',
      cumulativeTotal: false,
      cumulative: false,
      type: 'number',
      aggType: 'count',
      drillMembers: ['TrackedEvents.eventId', 'TrackedEvents.pageTitle'],
      drillMembersGrouped: {
        measures: [],
        dimensions: ['TrackedEvents.eventId', 'TrackedEvents.pageTitle'],
      },
      isVisible: true,
    },
  ],
  availableDimensions: [
    {
      name: 'Sessions.sessionID',
      title: 'Sessions Session Id',
      type: 'string',
      shortTitle: 'Session Id',
      suggestFilterValues: true,
      isVisible: false,
      public: false,
      primaryKey: true,
    },
    {
      name: 'TrackedEvents.pageTitle',
      title: 'Tracked Events Page Title',
      type: 'string',
      shortTitle: 'Page Title',
      suggestFilterValues: true,
      isVisible: true,
      public: true,
      primaryKey: false,
    },
    {
      name: 'TrackedEvents.pageUrl',
      title: 'Tracked Events Page Url',
      type: 'string',
      shortTitle: 'Page Url',
      suggestFilterValues: true,
      isVisible: true,
      public: true,
      primaryKey: false,
    },
  ],
  availableTimeDimensions: [
    {
      name: 'Sessions.startAt',
      title: 'Sessions Start at',
      type: 'time',
      shortTitle: 'Start at',
      suggestFilterValues: true,
      isVisible: true,
      public: true,
      primaryKey: false,
    },
    {
      name: 'Sessions.endAt',
      title: 'Sessions End at',
      type: 'time',
      shortTitle: 'End at',
      suggestFilterValues: true,
      isVisible: true,
      public: true,
      primaryKey: false,
    },
    {
      name: 'TrackedEvents.derivedTstamp',
      title: 'Tracked Events Derived Tstamp',
      type: 'time',
      shortTitle: 'Derived Tstamp',
      suggestFilterValues: true,
      isVisible: true,
      public: true,
      primaryKey: false,
    },
  ],
};

export const mockGroupUsageMetricsQueryResponse = {
  group: {
    id: 'gid://gitlab/Group/225',
    fullName: 'GitLab Org',
    avatarUrl: '/avatar.png',
    visibility: 'public',
    __typename: 'Group',
    groups: {
      __typename: 'ValueStreamDashboardCount',
      identifier: 'GROUPS',
      count: 58,
      recordedAt: '2023-11-27T23:59:59Z',
    },
    projects: {
      __typename: 'ValueStreamDashboardCount',
      identifier: 'PROJECTS',
      count: 97,
      recordedAt: '2023-11-27T21:59:59Z',
    },
    users: {
      __typename: 'ValueStreamDashboardCount',
      identifier: 'USERS',
      count: 90,
      recordedAt: '2023-11-27T21:59:59Z',
    },
    issues: {
      __typename: 'ValueStreamDashboardCount',
      identifier: 'ISSUES',
      count: 123,
      recordedAt: '2023-11-26T23:59:59Z',
    },
    pipelines: {
      __typename: 'ValueStreamDashboardCount',
      identifier: 'PIPELINES',
      count: 123,
      recordedAt: undefined,
    },
    merge_requests: {
      __typename: 'ValueStreamDashboardCount',
      identifier: 'MERGE_REQUESTS',
      count: 183,
      recordedAt: '2022-11-27T23:59:59Z',
    },
  },
  project: null,
};

export const mockProjectUsageMetricsQueryResponse = {
  group: null,
  project: {
    id: 'gid://gitlab/Project/7',
    nameWithNamespace: 'GitLab Org / GitLab',
    avatarUrl: '/avatar.png',
    visibility: 'internal',
    __typename: 'Project',
    issues: {
      __typename: 'ValueStreamDashboardCount',
      identifier: 'ISSUES',
      count: 133,
      recordedAt: '2023-11-26T23:59:59Z',
    },
    pipelines: {
      __typename: 'ValueStreamDashboardCount',
      identifier: 'PIPELINES',
      count: 150,
      recordedAt: undefined,
    },
    merge_requests: {
      __typename: 'ValueStreamDashboardCount',
      identifier: 'MERGE_REQUESTS',
      count: 200,
      recordedAt: '2022-11-27T23:59:59Z',
    },
  },
};

export const mockUsageGroupNamespaceData = {
  id: 225,
  avatarUrl: '/avatar.png',
  fullName: 'GitLab Org',
  namespaceType: 'Group',
  visibilityLevelIcon: 'earth',
  visibilityLevelTooltip:
    'Public - The group and any public projects can be viewed without any authentication.',
};

export const mockUsageProjectNamespaceData = {
  id: 7,
  avatarUrl: '/avatar.png',
  fullName: 'GitLab Org / GitLab',
  namespaceType: 'Project',
  visibilityLevelIcon: 'shield',
  visibilityLevelTooltip:
    'Internal - The project can be accessed by any logged in user except external users.',
};

export const mockGroupUsageMetrics = [
  {
    identifier: 'groups',
    value: 58,
    recordedAt: '2023-11-27T23:59:59Z',
    options: {
      title: 'Groups',
      titleIcon: 'group',
    },
  },
  {
    identifier: 'projects',
    value: 97,
    recordedAt: '2023-11-27T21:59:59Z',
    options: {
      title: 'Projects',
      titleIcon: 'project',
    },
  },
  {
    identifier: 'users',
    value: 90,
    recordedAt: '2023-11-27T21:59:59Z',
    options: {
      title: 'Users',
      titleIcon: 'user',
    },
  },
  {
    identifier: 'issues',
    value: 123,
    recordedAt: '2023-11-26T23:59:59Z',
    options: {
      title: 'Issues',
      titleIcon: 'issues',
    },
  },
  {
    identifier: 'merge_requests',
    value: 183,
    recordedAt: '2022-11-27T23:59:59Z',
    options: {
      title: 'Merge requests',
      titleIcon: 'merge-request',
    },
  },
  {
    identifier: 'pipelines',
    value: 123,
    recordedAt: undefined,
    options: {
      title: 'Pipelines',
      titleIcon: 'pipeline',
    },
  },
];

export const mockProjectUsageMetrics = [
  {
    identifier: 'issues',
    value: 133,
    recordedAt: '2023-11-26T23:59:59Z',
    options: {
      title: 'Issues',
      titleIcon: 'issues',
    },
  },
  {
    identifier: 'merge_requests',
    value: 200,
    recordedAt: '2022-11-27T23:59:59Z',
    options: {
      title: 'Merge requests',
      titleIcon: 'merge-request',
    },
  },
  {
    identifier: 'pipelines',
    value: 150,
    recordedAt: undefined,
    options: {
      title: 'Pipelines',
      titleIcon: 'pipeline',
    },
  },
];

export const mockUsageMetricsNoData = [
  {
    identifier: 'groups',
    value: 0,
    recordedAt: undefined,
    options: { title: 'Groups', titleIcon: 'group' },
  },
  {
    identifier: 'projects',
    value: 0,
    recordedAt: undefined,
    options: { title: 'Projects', titleIcon: 'project' },
  },
  {
    identifier: 'users',
    value: 0,
    recordedAt: undefined,
    options: { title: 'Users', titleIcon: 'user' },
  },
  {
    identifier: 'issues',
    value: 0,
    recordedAt: undefined,
    options: { title: 'Issues', titleIcon: 'issues' },
  },
  {
    identifier: 'merge_requests',
    value: 0,
    recordedAt: undefined,
    options: { title: 'Merge requests', titleIcon: 'merge-request' },
  },
  {
    identifier: 'pipelines',
    value: 0,
    recordedAt: undefined,
    options: { title: 'Pipelines', titleIcon: 'pipeline' },
  },
];

export const mockGroupUsageOverviewData = {
  namespace: mockUsageGroupNamespaceData,
  metrics: mockGroupUsageMetrics,
};

export const mockProjectUsageOverviewData = {
  namespace: mockUsageProjectNamespaceData,
  metrics: mockProjectUsageMetrics,
};

export const invalidVisualization = {
  type: 'LineChart',
  slug: 'invalid_visualization',
  version: 23, // bad version
  titlePropertyTypoOhNo: 'Cube line chart', // bad property name
  data: {
    type: 'cube_analytics',
    query: {
      users: {
        measures: ['TrackedEvents.count'],
        dimensions: ['TrackedEvents.eventType'],
      },
    },
  },
  errors: [
    `property '/version' is not: 1`,
    `property '/titlePropertyTypoOhNo' is invalid: error_type=schema`,
  ],
};

export const mockPanel = {
  ...getGraphQLDashboard({ slug: 'behavior', title: 'Behavior' }, true).panels.nodes[0],
  id: getUniquePanelId(),
};

export const TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      customizableDashboards: {
        nodes: [
          getGraphQLDashboard({ slug: 'audience', title: 'Audience' }, false),
          getGraphQLDashboard({ slug: 'behavior', title: 'Behavior' }, false),
          getGraphQLDashboard(
            { slug: 'new_dashboard', title: 'new_dashboard', userDefined: true },
            false,
          ),
          getGraphQLDashboard(
            { slug: 'audience_copy', title: 'Audience (Copy)', userDefined: true },
            false,
          ),
        ],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Project',
    },
  },
};

export const TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      customizableDashboards: {
        nodes: [getGraphQLDashboard({ slug: 'audience', title: 'Audience' })],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Project',
    },
  },
};

export const TEST_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      customizableDashboards: {
        nodes: [
          getGraphQLDashboard({
            slug: 'custom_dashboard',
            title: 'Custom Dashboard',
            userDefined: true,
          }),
        ],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Project',
    },
  },
};

export const TEST_VISUALIZATIONS_GRAPHQL_SUCCESS_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/73',
      customizableDashboardVisualizations: {
        nodes: [
          {
            slug: 'another_one',
            type: 'SingleStat',
            data: {
              type: 'cube_analytics',
              query: {
                measures: ['TrackedEvents.count'],
                filters: [
                  {
                    member: 'TrackedEvents.event',
                    operator: 'equals',
                    values: ['click'],
                  },
                ],
                limit: 100,
                timezone: 'UTC',
                dimensions: [],
                timeDimensions: [],
              },
            },
            options: {},
            __typename: 'CustomizableDashboardVisualization',
          },
        ],
      },
    },
  },
};

export const mockDateRangeFilterChangePayload = {
  startDate: new Date('2016-01-01'),
  endDate: new Date('2016-02-01'),
  dateRangeOption: 'foo',
};
