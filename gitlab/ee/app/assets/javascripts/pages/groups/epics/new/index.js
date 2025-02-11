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

  initWorkItemsRoot({ workspaceType: WORKSPACE_GROUP });
  initWorkItemsFeedback({
    feedbackIssue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/463598',
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
  const [{ initEpicForm }] = await Promise.all([import('ee/epic/new_epic_bundle')]);

  initEpicForm();
};

if (gon.features.workItemEpics) {
  initWorkItemEpicPage();
} else {
  initLegacyEpicPage();
}
