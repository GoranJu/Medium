import MockAdapter from 'axios-mock-adapter';
import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { cloneDeep } from 'lodash';
import { logError } from '~/lib/logger';
import axios from '~/lib/utils/axios_utils';
import getProjectDetailsQuery from 'ee/workspaces/common/graphql/queries/get_project_details.query.graphql';
import getRemoteDevelopmentClusterAgentsQuery from 'ee/workspaces/common/graphql/queries/get_remote_development_cluster_agents.query.graphql';
import GetProjectDetailsQuery from 'ee/workspaces/common/components/get_project_details_query.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import {
  GET_PROJECT_DETAILS_QUERY_RESULT,
  GET_REMOTE_DEVELOPMENT_CLUSTER_AGENTS_QUERY_RESULT_TWO_AGENTS,
  GET_REMOTE_DEVELOPMENT_CLUSTER_AGENTS_QUERY_RESULT_NO_AGENTS,
} from '../../mock_data';

Vue.use(VueApollo);

jest.mock('~/lib/logger');

describe('workspaces/common/components/get_project_details_query', () => {
  let getProjectDetailsQueryHandler;
  let getRemoteDevelopmentClusterAgentsQueryHandler;
  let glFeatures;
  let wrapper;
  let mockAxios;

  const projectFullPathFixture = 'gitlab-org/gitlab';

  const setupRemoteDevelopmentClusterAgentsQueryHandler = (responses) => {
    getRemoteDevelopmentClusterAgentsQueryHandler.mockResolvedValueOnce(responses);
  };

  const buildWrapper = async ({ projectFullPath = projectFullPathFixture } = {}) => {
    const apolloProvider = createMockApollo([
      [getProjectDetailsQuery, getProjectDetailsQueryHandler],
      [getRemoteDevelopmentClusterAgentsQuery, getRemoteDevelopmentClusterAgentsQueryHandler],
    ]);

    // noinspection JSCheckFunctionSignatures - TODO: Address in https://gitlab.com/gitlab-org/gitlab/-/issues/437600
    wrapper = shallowMountExtended(GetProjectDetailsQuery, {
      apolloProvider,
      provide: {
        glFeatures,
      },
      propsData: {
        projectFullPath,
      },
    });

    await waitForPromises();
  };

  const transformRemoveDevelopmentClusterAgentGraphQLResultToClusterAgents = (
    clusterAgentsGraphQLResult,
  ) =>
    clusterAgentsGraphQLResult.data.namespace.remoteDevelopmentClusterAgents.nodes.map(
      ({ id, name, project, workspacesAgentConfig }) => ({
        text: `${project.nameWithNamespace} / ${name}`,
        value: id,
        defaultMaxHoursBeforeTermination: workspacesAgentConfig.defaultMaxHoursBeforeTermination,
      }),
    );

  beforeEach(() => {
    getProjectDetailsQueryHandler = jest.fn();
    getRemoteDevelopmentClusterAgentsQueryHandler = jest.fn();

    logError.mockReset();

    getProjectDetailsQueryHandler.mockResolvedValueOnce(GET_PROJECT_DETAILS_QUERY_RESULT);
  });

  beforeEach(() => {
    mockAxios = new MockAdapter(axios);
  });

  afterEach(() => {
    mockAxios.restore();
  });

  describe('when project full path is provided', () => {
    it('executes get_project_details query', async () => {
      await buildWrapper();

      expect(getProjectDetailsQueryHandler).toHaveBeenCalledWith({
        projectFullPath: projectFullPathFixture,
      });
    });
  });

  describe('when the project is null', () => {
    beforeEach(() => {
      const customMockData = cloneDeep(GET_PROJECT_DETAILS_QUERY_RESULT);

      customMockData.data.project = null;

      getProjectDetailsQueryHandler.mockReset();
      getProjectDetailsQueryHandler.mockResolvedValueOnce(customMockData);
    });

    it('emits error event', async () => {
      await buildWrapper();

      expect(wrapper.emitted('error')).toEqual([[]]);
    });
  });

  describe('when project full path is not provided', () => {
    it('does not execute get_project_details query', async () => {
      // noinspection JSCheckFunctionSignatures -- This is incorrectly assuming the projectFullPath type is String due to its default value in the declaration
      await buildWrapper({ projectFullPath: null });

      expect(getProjectDetailsQueryHandler).not.toHaveBeenCalled();
    });
  });

  describe('when the project belongs to a group', () => {
    beforeEach(async () => {
      await buildWrapper();
    });

    it('executes getRemoteDevelopmentClusterAgents query', () => {
      expect(getRemoteDevelopmentClusterAgentsQueryHandler).toHaveBeenCalledTimes(1);
      expect(getRemoteDevelopmentClusterAgentsQueryHandler).toHaveBeenCalledWith({
        namespace: 'gitlab-org/subgroup',
      });
    });
  });

  describe('when the project does not have a repository', () => {
    beforeEach(async () => {
      setupRemoteDevelopmentClusterAgentsQueryHandler(
        GET_REMOTE_DEVELOPMENT_CLUSTER_AGENTS_QUERY_RESULT_TWO_AGENTS,
      );
      const customMockData = cloneDeep(GET_PROJECT_DETAILS_QUERY_RESULT);
      customMockData.data.project.repository = null;

      getProjectDetailsQueryHandler.mockReset();
      getProjectDetailsQueryHandler.mockResolvedValueOnce(customMockData);

      await buildWrapper();
    });

    it('emits result event with rootRef null', () => {
      expect(wrapper.emitted('result')[0][0]).toEqual({
        clusterAgents: transformRemoveDevelopmentClusterAgentGraphQLResultToClusterAgents(
          GET_REMOTE_DEVELOPMENT_CLUSTER_AGENTS_QUERY_RESULT_TWO_AGENTS,
        ),
        id: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.id,
        rootRef: null,
        nameWithNamespace: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.nameWithNamespace,
        fullPath: projectFullPathFixture,
      });
    });
  });

  describe('when getRemoteDevelopmentClusterAgents query contains one or more cluster agents', () => {
    beforeEach(async () => {
      setupRemoteDevelopmentClusterAgentsQueryHandler(
        GET_REMOTE_DEVELOPMENT_CLUSTER_AGENTS_QUERY_RESULT_TWO_AGENTS,
      );
      await buildWrapper();
    });

    it('emits result event with the cluster agents', async () => {
      await waitForPromises();

      expect(wrapper.emitted('result')[0][0]).toEqual({
        clusterAgents: transformRemoveDevelopmentClusterAgentGraphQLResultToClusterAgents(
          GET_REMOTE_DEVELOPMENT_CLUSTER_AGENTS_QUERY_RESULT_TWO_AGENTS,
        ),
        id: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.id,
        rootRef: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.repository.rootRef,
        fullPath: projectFullPathFixture,
        nameWithNamespace: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.nameWithNamespace,
      });
    });
  });

  describe('when getRemoteDevelopmentClusterAgents query does not contain cluster agents', () => {
    beforeEach(async () => {
      setupRemoteDevelopmentClusterAgentsQueryHandler(
        GET_REMOTE_DEVELOPMENT_CLUSTER_AGENTS_QUERY_RESULT_NO_AGENTS,
      );
      await buildWrapper();
    });

    it('emits result event with no cluster agents', async () => {
      await waitForPromises();

      expect(wrapper.emitted('result')[0][0]).toEqual({
        clusterAgents: [],
        id: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.id,
        rootRef: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.repository.rootRef,
        fullPath: projectFullPathFixture,
        nameWithNamespace: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.nameWithNamespace,
      });
    });
  });

  describe('when a project does not belong to a group', () => {
    beforeEach(async () => {
      const customMockData = cloneDeep(GET_PROJECT_DETAILS_QUERY_RESULT);

      customMockData.data.project.group = null;

      getProjectDetailsQueryHandler.mockReset();
      getProjectDetailsQueryHandler.mockResolvedValueOnce(customMockData);

      await buildWrapper();
    });

    it('does not execute the getRemoteDevelopmentClusterAgents query', () => {
      expect(getProjectDetailsQueryHandler).toHaveBeenCalled();
      expect(getRemoteDevelopmentClusterAgentsQueryHandler).not.toHaveBeenCalled();
    });

    it('emits result event with the project data', () => {
      expect(wrapper.emitted('result')[0][0]).toEqual({
        clusterAgents: [],
        id: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.id,
        rootRef: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.repository.rootRef,
        nameWithNamespace: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.nameWithNamespace,
        fullPath: projectFullPathFixture,
      });
    });
  });

  describe('when the project full path changes from group to not group', () => {
    beforeEach(async () => {
      setupRemoteDevelopmentClusterAgentsQueryHandler(
        GET_REMOTE_DEVELOPMENT_CLUSTER_AGENTS_QUERY_RESULT_TWO_AGENTS,
      );
      await waitForPromises();
    });

    it('emits empty clusters', async () => {
      const projectFullPath = 'new/path';

      await buildWrapper();

      expect(getRemoteDevelopmentClusterAgentsQueryHandler).toHaveBeenCalledTimes(1);

      const projectWithoutGroup = cloneDeep(GET_PROJECT_DETAILS_QUERY_RESULT);
      projectWithoutGroup.data.project.group = null;
      getProjectDetailsQueryHandler.mockResolvedValueOnce(projectWithoutGroup);

      // assert that we've only emitted once
      expect(wrapper.emitted('result')).toHaveLength(1);
      await wrapper.setProps({ projectFullPath });

      await waitForPromises();

      // assert against the last emitted result
      expect(wrapper.emitted('result')).toHaveLength(2);
      expect(wrapper.emitted('result')[1]).toEqual([
        {
          clusterAgents: [],
          id: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.id,
          rootRef: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.repository.rootRef,
          fullPath: projectFullPath,
          nameWithNamespace: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.nameWithNamespace,
        },
      ]);
    });
  });

  describe.each`
    queryName                                          | queryHandlerFactory
    ${'getProjectDetailsQuery'}                        | ${() => getProjectDetailsQueryHandler}
    ${'getRemoteDevelopmentClusterAgentsQueryHandler'} | ${() => getRemoteDevelopmentClusterAgentsQueryHandler}
  `('when the $queryName query fails', ({ queryHandlerFactory }) => {
    const error = new Error();

    beforeEach(() => {
      const mockedClusterAgentResponses = [
        GET_REMOTE_DEVELOPMENT_CLUSTER_AGENTS_QUERY_RESULT_NO_AGENTS,
      ];
      setupRemoteDevelopmentClusterAgentsQueryHandler(mockedClusterAgentResponses);

      const queryHandler = queryHandlerFactory();

      queryHandler.mockReset();
      queryHandler.mockRejectedValueOnce(error);
    });

    it('logs the error', async () => {
      expect(logError).not.toHaveBeenCalled();

      await buildWrapper();

      expect(logError).toHaveBeenCalledWith(error);
    });

    it('does not emit result event', async () => {
      await buildWrapper();

      expect(wrapper.emitted('result')).toBe(undefined);
    });

    it('emits error event', async () => {
      await buildWrapper();

      expect(wrapper.emitted('error')).toEqual([[]]);
    });
  });
});
