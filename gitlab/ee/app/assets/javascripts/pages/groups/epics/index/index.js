import { WORKSPACE_GROUP } from '~/issues/constants';

if (gon.features.workItemEpicsList && gon.features.namespaceLevelWorkItems) {
  import(/* webpackChunkName: 'workItemsApp' */ '~/work_items/index')
    .then(({ initWorkItemsRoot }) => {
      initWorkItemsRoot({ workItemType: 'epics', workspaceType: WORKSPACE_GROUP });
    })
    .catch(() => {});
} else {
  import(/* webpackChunkName: 'epicsList' */ 'ee/epics_list/epics_list_bundle')
    .then(({ default: initEpicsList }) => {
      initEpicsList({
        mountPointSelector: '#js-epics-list',
      });
    })
    .catch(() => {});
}
