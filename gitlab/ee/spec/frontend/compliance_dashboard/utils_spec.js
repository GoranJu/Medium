import timezoneMock from 'timezone-mock';
import { ApolloError } from '@apollo/client/core';
import * as utils from 'ee/compliance_dashboard/utils';
import {
  FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
  FRAMEWORKS_FILTER_TYPE_PROJECT,
  FRAMEWORKS_FILTER_TYPE_GROUP,
} from 'ee/compliance_dashboard/constants';

jest.mock('ee/audit_events/constants', () => ({
  CURRENT_DATE: new Date('2022 2 28'),
}));

describe('compliance report utils', () => {
  const projectIds = ['1', '2'];
  const projectGraphQlIds = ['gid://gitlab/Project/1', 'gid://gitlab/Project/2'];

  describe('isTopLevelGroup', () => {
    const rootGroupPath = '/root';
    const childGroupPath = '/root/child';
    const otherGroupPath = '/other';

    it('returns true for root group', () => {
      expect(utils.isTopLevelGroup(rootGroupPath, rootGroupPath)).toBe(true);
    });

    it('returns false for child group', () => {
      expect(utils.isTopLevelGroup(rootGroupPath, childGroupPath)).toBe(false);
    });

    it('returns false for other group', () => {
      expect(utils.isTopLevelGroup(rootGroupPath, otherGroupPath)).toBe(false);
    });
  });

  describe('parseViolationsQueryFilter', () => {
    it('returns the expected result', () => {
      const query = {
        projectIds,
        mergedAfter: '2021-12-06',
        mergedBefore: '2022-01-06',
        someExtraParam: 'someExtraParamValue',
        targetBranch: 'target-branch',
      };

      expect(utils.parseViolationsQueryFilter(query)).toStrictEqual({
        projectIds: projectGraphQlIds,
        mergedAfter: query.mergedAfter,
        mergedBefore: query.mergedBefore,
        targetBranch: query.targetBranch,
      });
    });

    describe('given a negative UTC timezone', () => {
      beforeAll(() => {
        timezoneMock.register('US/Pacific');
      });

      afterAll(() => {
        timezoneMock.unregister();
      });

      // See https://gitlab.com/gitlab-org/gitlab/-/issues/367675#note_1025545194
      it('ignores the users timezone and uses base UTC for the date', () => {
        const query = {
          projectIds,
          mergedAfter: '2021-12-06',
          mergedBefore: '2022-01-06',
          targetBranch: 'foo',
        };

        expect(utils.parseViolationsQueryFilter(query)).toStrictEqual({
          projectIds: projectGraphQlIds,
          mergedAfter: query.mergedAfter,
          mergedBefore: query.mergedBefore,
          targetBranch: query.targetBranch,
        });
      });
    });
  });

  describe('convertProjectIdsToGraphQl', () => {
    it('returns the expected result', () => {
      expect(utils.convertProjectIdsToGraphQl(projectIds)).toStrictEqual(projectGraphQlIds);
    });
  });

  describe('convertFrameworkIdToGraphQl', () => {
    it('should convert normal id to GraphQl compliance framework id', () => {
      const frameworkId = '123';
      expect(utils.convertFrameworkIdToGraphQl(frameworkId)).toBe(
        'gid://gitlab/ComplianceManagement::Framework/123',
      );
    });
  });

  describe('buildDefaultViolationsFilterParams', () => {
    it('returns the expected result with the default date range of 30 days', () => {
      const queryString = 'projectIds[]=20';

      expect(utils.buildDefaultViolationsFilterParams(queryString)).toStrictEqual({
        mergedAfter: '2022-01-29',
        mergedBefore: '2022-02-28',
        projectIds: ['20'],
      });
    });

    it('return the expected result when the query contains dates', () => {
      const queryString =
        'mergedAfter=2022-02-09&mergedBefore=2022-03-11&projectIds[]=20&tab=violations&targetBranch=foo';

      expect(utils.buildDefaultViolationsFilterParams(queryString)).toStrictEqual({
        mergedAfter: '2022-02-09',
        mergedBefore: '2022-03-11',
        projectIds: ['20'],
        tab: 'violations',
        targetBranch: 'foo',
      });
    });
  });

  describe('mapFiltersToUrlParams', () => {
    it('returns empty object when filters is empty', () => {
      expect(utils.mapFiltersToUrlParams([])).toEqual({});
    });

    it('maps filters to url params', () => {
      const filters = [
        { type: FRAMEWORKS_FILTER_TYPE_PROJECT, value: { data: 'my-project' } },
        { type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK, value: { data: 'my-framework1' } },
        { type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK, value: { data: 'my-framework2' } },
        { type: FRAMEWORKS_FILTER_TYPE_GROUP, value: { data: 'my-group' } },
      ];
      expect(utils.mapFiltersToUrlParams(filters)).toEqual({
        project: 'my-project',
        group: 'my-group',
        'framework[]': ['my-framework1', 'my-framework2'],
      });
    });

    it('maps frameworkExclude when operator is not equals', () => {
      const filters = [
        { type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK, value: { data: 'my-framework', operator: '!=' } },
      ];
      expect(utils.mapFiltersToUrlParams(filters)).toEqual({
        'not[framework][]': ['my-framework'],
      });
    });

    it('maps frameworkExclude when operator is equals', () => {
      const filters = utils.mapQueryToFilters({
        project: 'my-project',
        'not[framework][]': ['my-framework1', 'my-framework2'],
      });

      expect(filters).toEqual([
        {
          type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
          value: { data: 'my-framework1', operator: '!=' },
        },
        {
          type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
          value: { data: 'my-framework2', operator: '!=' },
        },
        {
          type: FRAMEWORKS_FILTER_TYPE_PROJECT,
          value: { data: 'my-project', operator: 'matches' },
        },
      ]);
    });
  });

  describe('mapQueryToFilters', () => {
    it('returns empty array when query params are empty', () => {
      expect(utils.mapQueryToFilters({})).toEqual([]);
    });

    it('maps query params to filters', () => {
      const queryParams = {
        project: 'my-project',
        group: 'my-group',
        'framework[]': ['my-framework1', 'my-framework2'],
      };
      expect(utils.mapQueryToFilters(queryParams)).toEqual([
        { type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK, value: { data: 'my-framework1', operator: '=' } },
        { type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK, value: { data: 'my-framework2', operator: '=' } },
        {
          type: FRAMEWORKS_FILTER_TYPE_PROJECT,
          value: { data: 'my-project', operator: 'matches' },
        },
        { type: FRAMEWORKS_FILTER_TYPE_GROUP, value: { data: 'my-group', operator: 'matches' } },
      ]);
    });

    it('maps frameworkExclude when query param is set', () => {
      const queryParams = { 'not[framework][]': ['my-framework1', 'my-framework2'] };
      expect(utils.mapQueryToFilters(queryParams)).toEqual([
        {
          type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
          value: { data: 'my-framework1', operator: '!=' },
        },
        {
          type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
          value: { data: 'my-framework2', operator: '!=' },
        },
      ]);
    });
  });

  describe('checkFilterForChange', () => {
    it('returns false when both filters are empty', () => {
      expect(utils.checkFilterForChange({ currentFilters: [], newFilters: [] })).toBe(false);
    });

    it('returns true when project filter has changed', () => {
      const currentFilters = { project: 'framework 1', framework: '', frameworkExclude: false };
      const newFilters = { project: 'framework 2', framework: '', frameworkExclude: false };
      expect(utils.checkFilterForChange({ currentFilters, newFilters })).toBe(true);
    });

    it('returns true when framework filter has changed', () => {
      const currentFilters = { project: '', 'framework[]': ['old-framework'] };
      const newFilters = {
        project: '',
        framework: ['old-framework', 'new-framework'],
        frameworkExclude: false,
      };
      expect(utils.checkFilterForChange({ currentFilters, newFilters })).toBe(true);
    });

    it('returns true when group filter has changed', () => {
      const currentFilters = { project: '', 'framework[]': ['old-framework'], group: 'old-group' };
      const newFilters = {
        ...currentFilters,
        group: 'new-group',
      };
      expect(utils.checkFilterForChange({ currentFilters, newFilters })).toBe(true);
    });

    it('returns true when frameworkExclude filter has changed', () => {
      const currentFilters = {
        project: '',
        'framework[]': ['current-framework'],
      };
      const newFilters = { project: '', 'not[framework][]': ['current-framework'] };
      expect(utils.checkFilterForChange({ currentFilters, newFilters })).toBe(true);
    });

    it('returns false when filters have not changed', () => {
      const currentFilters = {
        project: '',
        framework: 'current-framework',
        frameworkExclude: false,
      };
      const newFilters = { project: '', framework: 'current-framework', frameworkExclude: false };
      expect(utils.checkFilterForChange({ currentFilters, newFilters })).toBe(false);
    });
  });

  describe('isGraphqlFieldMissingError', () => {
    const graphqlError = new ApolloError({
      graphQLErrors: [
        {
          message: "Field 'foo' doesn't exist on type 'Project'",
        },
      ],
    });

    it('returns true when error looks like graphql one and references correct field', () => {
      expect(utils.isGraphqlFieldMissingError(graphqlError, 'foo')).toBe(true);
    });

    it('returns false when error looks like graphql one but references other field', () => {
      expect(utils.isGraphqlFieldMissingError(graphqlError, 'bar')).toBe(false);
    });
    it('returns false for other errors', () => {
      expect(utils.isGraphqlFieldMissingError(new Error('test'), 'foo')).toBe(false);
    });
  });
});
