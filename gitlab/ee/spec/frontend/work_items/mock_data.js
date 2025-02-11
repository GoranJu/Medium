export const createWorkItemMutationResponse = {
  data: {
    workItemCreate: {
      __typename: 'WorkItemCreatePayload',
      workItem: {
        __typename: 'WorkItem',
        id: 'gid://gitlab/WorkItem/1',
        iid: '1',
        title: 'Updated title',
        state: 'OPEN',
        description: 'description',
        confidential: false,
        createdAt: '2022-08-03T12:41:54Z',
        closedAt: null,
        webUrl: 'http://127.0.0.1:3000/groups/gitlab-org/-/work_items/1',
        project: {
          __typename: 'Project',
          id: '1',
          fullPath: 'test-project-path',
          archived: false,
        },
        workItemType: {
          __typename: 'WorkItemType',
          id: 'gid://gitlab/WorkItems::Type/5',
          name: 'Task',
          iconName: 'issue-type-task',
        },
        userPermissions: {
          deleteWorkItem: false,
          updateWorkItem: false,
        },
        mockWidgets: [],
        widgets: [],
      },
      errors: [],
    },
  },
};

export const createWorkItemMutationErrorResponse = {
  data: {
    workItemCreate: {
      __typename: 'WorkItemCreatePayload',
      workItem: null,
      errors: ['Title is too long (maximum is 255 characters)'],
    },
  },
};

export const workItemObjectiveMetadataWidgetsEE = {
  HEALTH_STATUS: {
    type: 'HEALTH_STATUS',
    __typename: 'WorkItemWidgetHealthStatus',
    healthStatus: 'onTrack',
    rolledUpHealthStatus: [],
  },
  PROGRESS: {
    type: 'PROGRESS',
    __typename: 'WorkItemWidgetProgress',
    progress: 10,
    updatedAt: new Date(),
  },
  WEIGHT: {
    type: 'WEIGHT',
    weight: 1,
    rolledUpWeight: 0,
    widgetDefinition: {
      editable: true,
      rollUp: false,
      __typename: 'WorkItemWidgetDefinitionWeight',
    },
    __typename: 'WorkItemWidgetWeight',
  },
  ITERATION: {
    type: 'ITERATION',
    __typename: 'WorkItemWidgetIteration',
    iteration: {
      description: null,
      id: 'gid://gitlab/Iteration/1',
      iid: '12',
      title: 'Iteration title',
      startDate: '2023-12-19',
      dueDate: '2024-01-15',
      updatedAt: new Date(),
      iterationCadence: {
        title: 'Iteration 101',
        __typename: 'IterationCadence',
      },
      __typename: 'Iteration',
    },
  },
  START_AND_DUE_DATE: {
    type: 'START_AND_DUE_DATE',
    dueDate: '2024-06-27',
    startDate: '2024-01-01',
    __typename: 'WorkItemWidgetStartAndDueDate',
  },
};

export const workItemTaskEE = {
  id: 'gid://gitlab/WorkItem/4',
  iid: '4',
  workItemType: {
    id: 'gid://gitlab/WorkItems::Type/5',
    name: 'Task',
    iconName: 'issue-type-task',
    __typename: 'WorkItemType',
  },
  title: 'bar',
  state: 'OPEN',
  confidential: false,
  reference: 'test-project-path#4',
  namespace: {
    __typename: 'Project',
    id: '1',
    fullPath: 'test-project-path',
    name: 'Project name',
  },
  createdAt: '2022-08-03T12:41:54Z',
  closedAt: null,
  webUrl: '/gitlab-org/gitlab-test/-/work_items/4',
  widgets: [
    workItemObjectiveMetadataWidgetsEE.WEIGHT,
    workItemObjectiveMetadataWidgetsEE.ITERATION,
    workItemObjectiveMetadataWidgetsEE.START_AND_DUE_DATE,
  ],
  __typename: 'WorkItem',
};

export const workItemColorWidget = {
  id: 'gid://gitlab/WorkItem/1',
  iid: '1',
  title: 'Work item epic 5',
  namespace: {
    id: 'gid://gitlab/Group/1',
    fullPath: 'gitlab-org',
    name: 'Gitlab Org',
    __typename: 'Namespace',
  },
  workItemType: {
    id: 'gid://gitlab/WorkItems::Type/1',
    name: 'Epic',
    iconName: 'issue-type-epic',
    __typename: 'WorkItemType',
  },
  widgets: [
    {
      color: '#1068bf',
      textColor: '#FFFFFF',
      type: 'COLOR',
      __typename: 'WorkItemWidgetColor',
    },
  ],
  __typename: 'WorkItem',
};

export const workItemParent = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/1',
    },
  },
};

export const mockRolledUpHealthStatus = [
  {
    count: 1,
    healthStatus: 'onTrack',
    __typename: 'WorkItemWidgetHealthStatusCount',
  },
  {
    count: 0,
    healthStatus: 'needsAttention',
    __typename: 'WorkItemWidgetHealthStatusCount',
  },
  {
    count: 1,
    healthStatus: 'atRisk',
    __typename: 'WorkItemWidgetHealthStatusCount',
  },
];

export const workItemChangeTypeWidgets = {
  ITERATION: {
    type: 'ITERATION',
    iteration: {
      id: 'gid://gitlab/Iteration/86312',
      __typename: 'Iteration',
    },
    __typename: 'WorkItemWidgetIteration',
  },
  WEIGHT: {
    type: 'WEIGHT',
    weight: 1,
    __typename: 'WorkItemWidgetWeight',
  },
  PROGRESS: {
    type: 'PROGRESS',
    progress: 33,
    updatedAt: '2024-12-05T16:24:56Z',
    __typename: 'WorkItemWidgetProgress',
  },
  MILESTONE: {
    type: 'MILESTONE',
    __typename: 'WorkItemWidgetMilestone',
    milestone: {
      __typename: 'Milestone',
      id: 'gid://gitlab/Milestone/30',
      title: 'v4.0',
      state: 'active',
      expired: false,
      startDate: '2022-10-17',
      dueDate: '2022-10-24',
      webPath: '123',
    },
  },
};

export const promoteToEpicMutationResponse = {
  data: {
    promoteToEpic: {
      epic: {
        id: 'gid://gitlab/Epic/225',
        webPath: '/groups/gitlab-org/-/epics/265',
        __typename: 'Epic',
      },
      errors: [],
      __typename: 'PromoteToEpicPayload',
    },
  },
};

export const getEpicWeightWidgetDefinitions = (editable = false) => {
  return [
    {
      id: 'gid://gitlab/WorkItems::Type/6',
      name: 'Epic',
      widgetDefinitions: [
        {
          type: 'WEIGHT',
          editable,
          rollUp: false,
          __typename: 'WorkItemWidgetDefinitionWeight',
        },
      ],
      __typename: 'WorkItemType',
    },
  ];
};

export const namespaceWorkItemsWithoutEpicSupport = {
  data: {
    workspace: {
      id: 'gid://gitlab/Group/14',
      workItemTypes: {
        nodes: [
          {
            id: 'gid://gitlab/WorkItems::Type/1',
            name: 'Issue',
            iconName: 'issue-type-issue',
            supportedConversionTypes: [
              {
                id: 'gid://gitlab/WorkItems::Type/2',
                name: 'Incident',
                __typename: 'WorkItemType',
              },
              {
                id: 'gid://gitlab/WorkItems::Type/5',
                name: 'Task',
                __typename: 'WorkItemType',
              },
              {
                id: 'gid://gitlab/WorkItems::Type/3',
                name: 'Test Case',
                __typename: 'WorkItemType',
              },
              {
                id: 'gid://gitlab/WorkItems::Type/9',
                name: 'Ticket',
                __typename: 'WorkItemType',
              },
            ],
            widgetDefinitions: [
              {
                type: 'ASSIGNEES',
                allowsMultipleAssignees: true,
                canInviteMembers: false,
                __typename: 'WorkItemWidgetDefinitionAssignees',
              },
              {
                type: 'AWARD_EMOJI',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'CRM_CONTACTS',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'CURRENT_USER_TODOS',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'DESCRIPTION',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'DESIGNS',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'DEVELOPMENT',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'EMAIL_PARTICIPANTS',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'HIERARCHY',
                allowedChildTypes: {
                  nodes: [
                    {
                      id: 'gid://gitlab/WorkItems::Type/5',
                      name: 'Task',
                      __typename: 'WorkItemType',
                    },
                  ],
                  __typename: 'WorkItemTypeConnection',
                },
                __typename: 'WorkItemWidgetDefinitionHierarchy',
              },
              {
                type: 'ITERATION',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'LABELS',
                allowsScopedLabels: false,
                __typename: 'WorkItemWidgetDefinitionLabels',
              },
              {
                type: 'LINKED_ITEMS',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'MILESTONE',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'NOTES',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'NOTIFICATIONS',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'PARTICIPANTS',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'START_AND_DUE_DATE',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'TIME_TRACKING',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'WEIGHT',
                editable: true,
                rollUp: false,
                __typename: 'WorkItemWidgetDefinitionWeight',
              },
            ],
            __typename: 'WorkItemType',
          },
        ],
      },
    },
  },
};
