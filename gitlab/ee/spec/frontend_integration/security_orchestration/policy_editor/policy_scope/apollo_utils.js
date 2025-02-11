import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { TYPE_COMPLIANCE_FRAMEWORK } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import {
  mockPageInfo,
  validCreateResponse,
} from 'ee_jest/groups/settings/compliance_frameworks/mock_data';
import getComplianceFrameworkQuery from 'ee/graphql_shared/queries/get_compliance_framework.query.graphql';
import createComplianceFrameworkMutation from 'ee/groups/settings/compliance_frameworks/graphql/queries/create_compliance_framework.mutation.graphql';
import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
import getSppLinkedGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_groups.graphql';
import getGroupProjects from 'ee/security_orchestration/graphql/queries/get_group_projects.query.graphql';
import securityPolicyProjectCreated from 'ee/security_orchestration/graphql/queries/security_policy_project_created.subscription.graphql';
import { createSppSubscriptionHandler } from '../utils';

const defaultNodes = [
  {
    id: convertToGraphQLId(TYPE_COMPLIANCE_FRAMEWORK, 1),
    name: 'A1',
    default: true,
    description: 'description 1',
    color: '#cd5b45',
    pipelineConfigurationFullPath: 'path 1',
    projects: { nodes: [] },
  },
  {
    id: convertToGraphQLId(TYPE_COMPLIANCE_FRAMEWORK, 2),
    name: 'B2',
    default: false,
    description: 'description 2',
    color: '#cd5b45',
    pipelineConfigurationFullPath: 'path 2',
    projects: {
      nodes: [
        {
          id: '1',
          name: 'project-1',
          webUrl: 'gid://gitlab/Project/1',
        },
      ],
    },
  },
  {
    id: convertToGraphQLId(TYPE_COMPLIANCE_FRAMEWORK, 3),
    name: 'a3',
    default: true,
    description: 'description 3',
    color: '#cd5b45',
    pipelineConfigurationFullPath: 'path 3',
    projects: {
      nodes: [
        {
          id: '1',
          name: 'project-1',
          webUrl: 'gid://gitlab/Project/1',
        },
        {
          id: '2',
          name: 'project-2',
          webUrl: 'gid://gitlab/Project/2',
        },
      ],
    },
  },
];

export const createSppLinkedItemsHandler = ({ projects = [], namespaces = [], groups = [] } = {}) =>
  jest.fn().mockResolvedValue({
    data: {
      project: {
        id: '1',
        securityPolicyProjectLinkedProjects: {
          nodes: projects,
          pageInfo: mockPageInfo(),
        },
        securityPolicyProjectLinkedNamespaces: {
          nodes: namespaces,
          pageInfo: mockPageInfo(),
        },
        securityPolicyProjectLinkedGroups: {
          nodes: groups,
          pageInfo: mockPageInfo(),
        },
      },
    },
  });

export const createSppLinkedGroupsHandler = ({ groups = [] } = {}) =>
  jest.fn().mockResolvedValue({
    data: {
      project: {
        id: '1',
        securityPolicyProjectLinkedGroups: {
          nodes: groups,
          pageInfo: mockPageInfo(),
        },
      },
    },
  });

export const mockApolloHandlers = (nodes = defaultNodes) => {
  return {
    complianceFrameworks: jest.fn().mockResolvedValue({
      data: {
        namespace: {
          id: 1,
          name: 'name',
          complianceFrameworks: {
            pageInfo: mockPageInfo(),
            nodes,
          },
        },
      },
    }),
    createFrameworkHandler: jest.fn().mockResolvedValue(validCreateResponse),
  };
};

const mockApolloProjectHandlers = () => {
  return {
    getGroupProjects: jest.fn().mockResolvedValue({
      data: {
        id: 1,
        group: {
          id: 2,
          projects: {
            nodes: [],
          },
        },
      },
    }),
  };
};

export const defaultHandlers = {
  ...mockApolloHandlers(),
  sppLinkedItemsHandler: createSppLinkedItemsHandler(),
  sppLinkedGroupsHandler: createSppLinkedGroupsHandler(),
  securityPolicyProjectCreatedHandler: createSppSubscriptionHandler(),
};

export const createMockApolloProvider = (handlers = defaultHandlers) => {
  Vue.use(VueApollo);

  return createMockApollo([
    [getComplianceFrameworkQuery, handlers.complianceFrameworks],
    [createComplianceFrameworkMutation, handlers.createFrameworkHandler],
    [getSppLinkedProjectsGroups, handlers.sppLinkedItemsHandler],
    [getSppLinkedGroups, handlers.sppLinkedGroupsHandler],
    [getGroupProjects, mockApolloProjectHandlers],
    [securityPolicyProjectCreated, handlers.securityPolicyProjectCreatedHandler],
  ]);
};
