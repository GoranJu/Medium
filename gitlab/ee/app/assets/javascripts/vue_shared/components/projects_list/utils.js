import {
  availableGraphQLProjectActions as availableGraphQLProjectActionsCE,
  renderDeleteSuccessToast as renderDeleteSuccessToastCE,
  deleteParams as deleteParamsCE,
} from '~/vue_shared/components/projects_list/utils';
import { ACTION_RESTORE, BASE_ACTIONS } from '~/vue_shared/components/list_actions/constants';
import toast from '~/vue_shared/plugins/global_toast';
import { sprintf, __ } from '~/locale';

const isAdjournedDeletionEnabled = (project) => {
  // Check if enabled at the project level or globally
  return (
    project.isAdjournedDeletionEnabled ||
    gon?.licensed_features?.adjournedDeletionForProjectsAndGroups
  );
};

// Exports override for EE
// eslint-disable-next-line import/export
export * from '~/vue_shared/components/projects_list/utils';

// Exports override for EE
// eslint-disable-next-line import/export
export const availableGraphQLProjectActions = ({ userPermissions, markedForDeletionOn }) => {
  const availableActions = availableGraphQLProjectActionsCE({ userPermissions });

  if (userPermissions.removeProject && markedForDeletionOn) {
    availableActions.push(ACTION_RESTORE);
  }

  return availableActions.sort((a, b) => BASE_ACTIONS[a].order - BASE_ACTIONS[b].order);
};

export const renderRestoreSuccessToast = (project) => {
  toast(
    sprintf(__("Project '%{project_name}' has been successfully restored."), {
      project_name: project.name,
    }),
  );
};

// Exports override for EE
// eslint-disable-next-line import/export
export const renderDeleteSuccessToast = (project) => {
  // Adjourned deletion feature is not available, call CE function.
  if (!isAdjournedDeletionEnabled(project)) {
    renderDeleteSuccessToastCE(project);
    return;
  }

  // Project has been marked for delayed deletion so will now be deleted immediately.
  if (project.markedForDeletionOn) {
    toast(
      sprintf(__("Project '%{project_name}' is being deleted."), {
        project_name: project.name,
      }),
    );

    return;
  }

  // Adjourned deletion is available at the project level, delete delayed.
  if (project.isAdjournedDeletionEnabled) {
    toast(
      sprintf(__("Project '%{project_name}' will be deleted on %{date}."), {
        project_name: project.name,
        date: project.permanentDeletionDate,
      }),
    );

    return;
  }

  // Adjourned deletion is available globally but not at the project level.
  // This means we are deleting a free project. It will be deleted delayed but can only be
  // restored by an admin.
  toast(
    sprintf(__("Deleting project '%{project_name}'. All data will be removed on %{date}."), {
      project_name: project.name,
      date: project.permanentDeletionDate,
    }),
  );
};

// Exports override for EE
// eslint-disable-next-line import/export
export const deleteParams = (project) => {
  // Adjourned deletion feature is not available, call CE function.
  if (!isAdjournedDeletionEnabled(project)) {
    return deleteParamsCE();
  }

  // Project has been marked for delayed deletion so will now be deleted immediately.
  if (project.markedForDeletionOn) {
    return { permanently_remove: true, full_path: project.fullPath };
  }

  // Adjourned deletion feature is available.
  return {};
};
