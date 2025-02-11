import createMockApollo from 'helpers/mock_apollo_helper';
import { updateNewWorkItemCache } from '~/work_items/graphql/resolvers';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import updateNewWorkItemMutation from '~/work_items/graphql/update_new_work_item.mutation.graphql';
import {
  WIDGET_TYPE_COLOR,
  WIDGET_TYPE_START_AND_DUE_DATE,
  WIDGET_TYPE_HEALTH_STATUS,
  WIDGET_TYPE_ITERATION,
  WIDGET_TYPE_WEIGHT,
} from '~/work_items/constants';
import { createWorkItemQueryResponse } from 'jest/work_items/mock_data';

describe('EE work items graphql resolvers', () => {
  describe('updateNewWorkItemCache', () => {
    let mockApolloClient;

    const fullPath = 'fullPath';
    const fullPathWithId = 'fullPath-issue-id';
    const iid = 'new-work-item-iid';
    const mockLocalIteration = {
      __typename: 'Iteration',
      id: 'gid://gitlab/Iteration/46697',
      title: null,
      startDate: '2024-08-26',
      dueDate: '2024-09-01',
      webUrl: 'http://127.0.0.1:3000/groups/flightjs/-/iterations/46697',
      iterationCadence: {
        __typename: 'IterationCadence',
        id: 'gid://gitlab/Iterations::Cadence/5042',
        title:
          'Tenetur voluptatem necessitatibus velit natus et ut animi deleniti adipisci voluptas.',
      },
    };

    const mutate = (input) => {
      mockApolloClient.mutate({
        mutation: updateNewWorkItemMutation,
        variables: {
          input: {
            workItemType: 'issue',
            fullPath,
            ...input,
          },
        },
      });
    };

    const query = async (widgetName = null) => {
      const queryResult = await mockApolloClient.query({
        query: workItemByIidQuery,
        variables: { fullPath: fullPathWithId, iid },
      });

      if (widgetName == null) return queryResult.data.workspace.workItem;

      return queryResult.data.workspace.workItem.widgets.find(({ type }) => type === widgetName);
    };

    beforeEach(() => {
      const mockApollo = createMockApollo([], {
        Mutation: {
          updateNewWorkItem(_, { input }, { cache }) {
            updateNewWorkItemCache(input, cache);
          },
        },
      });
      mockApollo.clients.defaultClient.cache.writeQuery({
        query: workItemByIidQuery,
        variables: { fullPath: fullPathWithId, iid },
        data: createWorkItemQueryResponse.data,
      });
      mockApolloClient = mockApollo.clients.defaultClient;
    });

    describe('title input', () => {
      it('updates title when added', async () => {
        await mutate({ title: 'Issue 1' });

        const queryResult = await query();
        expect(queryResult.title).toBe('Issue 1');
      });

      it('updates title if it becomes empty', async () => {
        await mutate({ title: '' });

        const queryResult = await query();
        expect(queryResult.title).toBe('');
      });

      it('does not update title if undefined (another input was updated)', async () => {
        await mutate({ title: 'Issue 2' });

        const queryResult1 = await query();
        expect(queryResult1.title).toBe('Issue 2');

        await mutate({ title: undefined });

        const queryResult2 = await query();
        expect(queryResult2.title).toBe('Issue 2');
      });
    });

    describe('with healthStatus input', () => {
      it('updates health status', async () => {
        await mutate({ healthStatus: 'onTrack' });

        const queryResult = await query(WIDGET_TYPE_HEALTH_STATUS);
        expect(queryResult).toMatchObject({ healthStatus: 'onTrack' });
      });

      it('clears health status', async () => {
        await mutate({ healthStatus: null });

        const queryResult = await query(WIDGET_TYPE_HEALTH_STATUS);
        expect(queryResult).toMatchObject({ healthStatus: null });
      });
    });

    describe('with color input', () => {
      it('updates color', async () => {
        await mutate({ color: '#000' });

        const queryResult = await query(WIDGET_TYPE_COLOR);
        expect(queryResult).toMatchObject({ color: '#000' });
      });
    });

    describe('with rolledUpDates input', () => {
      it('updates rolledUpDates', async () => {
        await mutate({
          rolledUpDates: {
            isFixed: true,
            rollUp: true,
            dueDate: '2024-02-02',
            startDate: '2023-12-22',
          },
        });

        const queryResult = await query(WIDGET_TYPE_START_AND_DUE_DATE);
        expect(queryResult).toMatchObject({
          isFixed: true,
          rollUp: true,
          dueDate: '2024-02-02',
          startDate: '2023-12-22',
        });
      });
    });

    describe('with iteration input', () => {
      it('updates iteration', async () => {
        await mutate({
          iteration: mockLocalIteration,
        });

        const queryResult = await query(WIDGET_TYPE_ITERATION);
        expect(queryResult).toMatchObject({
          iteration: mockLocalIteration,
        });
      });
    });

    describe('with weight input', () => {
      it('updates weight if value is a number', async () => {
        await mutate({ weight: 2 });

        const queryResult = await query(WIDGET_TYPE_WEIGHT);
        expect(queryResult).toMatchObject({ weight: 2 });
      });

      it('updates weight if value is number 0', async () => {
        await mutate({ weight: 0 });

        const queryResult = await query(WIDGET_TYPE_WEIGHT);
        expect(queryResult).toMatchObject({ weight: 0 });
      });

      it('does not update weight if value is not changed/undefined', async () => {
        await mutate({ weight: undefined });

        const queryResult = await query(WIDGET_TYPE_WEIGHT);
        expect(queryResult).toMatchObject({ weight: 2 });
      });

      it('updates weight if cleared', async () => {
        await mutate({ weight: null });

        const queryResult = await query(WIDGET_TYPE_WEIGHT);
        expect(queryResult).toMatchObject({ weight: null });
      });
    });
  });
});
