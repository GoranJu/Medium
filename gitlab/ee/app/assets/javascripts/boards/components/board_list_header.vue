<script>
import BoardListHeaderFoss from '~/boards/components/board_list_header.vue';
import { fetchPolicies } from '~/lib/graphql';
import { n__, __, sprintf } from '~/locale';
import { setError } from '~/boards/graphql/cache_updates';
import { listsDeferredQuery } from '../constants';

// This is a false violation of @gitlab/no-runtime-template-compiler, since it
// extends a valid Vue single file component.
// eslint-disable-next-line @gitlab/no-runtime-template-compiler
export default {
  extends: BoardListHeaderFoss,
  inject: ['weightFeatureAvailable', 'isEpicBoard'],
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    boardList: {
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      query() {
        return listsDeferredQuery[this.issuableType].query;
      },
      variables() {
        return this.countQueryVariables;
      },
      update(data) {
        return this.isEpicBoard ? data.epicBoardList : data.boardList;
      },
      error(error) {
        setError({
          error,
          message: this.$options.i18n.fetchError,
        });
      },
    },
  },
  computed: {
    countIcon() {
      return this.isEpicBoard ? 'epic' : 'issues';
    },
    itemsTooltipLabel() {
      const { maxIssueCount } = this.list;
      if (maxIssueCount > 0) {
        return sprintf(__('%{itemsCount} issues with a limit of %{maxIssueCount}'), {
          itemsCount: this.itemsCount,
          maxIssueCount,
        });
      }

      return this.isEpicBoard
        ? n__(`%d epic`, `%d epics`, this.itemsCount)
        : n__(`%d issue`, `%d issues`, this.itemsCount);
    },
    weightCountToolTip() {
      if (!this.weightFeatureAvailable) {
        return null;
      }

      return sprintf(__('%{totalIssueWeight} total weight'), {
        totalIssueWeight: this.totalIssueWeight,
      });
    },
    totalIssueWeight() {
      if (this.isEpicBoard) {
        return this.boardList?.metadata?.totalWeight || 0;
      }

      return this.boardList?.totalIssueWeight;
    },
  },
  watch: {
    boardList: {
      handler() {
        if (!this.isEpicBoard) {
          this.$emit('setTotalIssuesCount', this.boardList?.id, this.boardList?.issuesCount ?? 0);
        }
      },
    },
  },
};
</script>
