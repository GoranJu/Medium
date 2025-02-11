import { issuableInitialDataById, isLegacyIssueType } from '~/issues/show/utils/issuable_data';

const initLegacyIssuePage = async () => {
  const imports = [import('ee/issues'), import('~/issues'), import('~/user_callout')];

  const [
    { initRelatedFeatureFlags, initUnableToLinkVulnerabilityError },
    { initShow },
    userCalloutModule,
  ] = await Promise.all(imports);

  initShow();
  initRelatedFeatureFlags();
  initUnableToLinkVulnerabilityError();

  const UserCallout = userCalloutModule.default;

  new UserCallout({ className: 'js-epics-sidebar-callout' }); // eslint-disable-line no-new
  new UserCallout({ className: 'js-weight-sidebar-callout' }); // eslint-disable-line no-new
};

const initWorkItemPage = async () => {
  const [{ initWorkItemsRoot }] = await Promise.all([import('~/work_items')]);

  initWorkItemsRoot({ workItemType: 'issue' });
};

const issuableData = issuableInitialDataById('js-issuable-app');

if (
  !isLegacyIssueType(issuableData) &&
  gon.features.workItemsViewPreference &&
  gon.current_user_use_work_items_view
) {
  initWorkItemPage();
} else {
  initLegacyIssuePage();
}
