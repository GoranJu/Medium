const initWorkItemEpicPage = async () => {
  const [
    { WORKSPACE_GROUP },
    { FEATURE_NAME, NEW_EPIC_FEEDBACK_PROMPT_EXPIRY },
    { initWorkItemsRoot },
    { initWorkItemsFeedback },
    { __ },
  ] = await Promise.all([
    import('~/issues/constants'),
    import('~/work_items/constants'),
    import('~/work_items'),
    import('~/work_items_feedback'),
    import('~/locale'),
  ]);

  initWorkItemsRoot({ workItemType: 'epics', workspaceType: WORKSPACE_GROUP });
  initWorkItemsFeedback({
    feedbackIssue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/494462',
    feedbackIssueText: __('Provide feedback on the experience'),
    content: __(
      'We’ve introduced some improvements to the epic page such as real time updates, additional features, and a refreshed design. Have questions or thoughts on the changes?',
    ),
    title: __('New epic look'),
    featureName: FEATURE_NAME,
    expiry: NEW_EPIC_FEEDBACK_PROMPT_EXPIRY,
  });
};

const initLegacyEpicPage = async () => {
  const [
    { addShortcutsExtension },
    { default: ShortcutsEpic },
    { default: initEpicApp },
    { default: initNotesApp },
    { default: ZenMode },
    { default: initAwardsApp },
  ] = await Promise.all([
    import('~/behaviors/shortcuts'),
    import('ee/behaviors/shortcuts/shortcuts_epic'),
    import('ee/epic/epic_bundle'),
    import('~/notes'),
    import('~/zen_mode'),
    import('~/emoji/awards_app'),
  ]);

  initNotesApp();
  initEpicApp();

  import('ee/linked_epics/linked_epics_bundle').then((m) => m.default()).catch(() => {});

  requestIdleCallback(() => {
    addShortcutsExtension(ShortcutsEpic);
    initAwardsApp(document.getElementById('js-vue-awards-block'));
    new ZenMode(); // eslint-disable-line no-new
  });
};

if (gon.features.workItemEpics) {
  initWorkItemEpicPage();
} else {
  initLegacyEpicPage();
}
