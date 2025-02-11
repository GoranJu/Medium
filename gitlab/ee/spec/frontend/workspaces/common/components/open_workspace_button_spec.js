import { shallowMount } from '@vue/test-utils';
import { GlButton } from '@gitlab/ui';
import OpenWorkspaceButton from 'ee/workspaces/common/components/open_workspace_button.vue';
import { WORKSPACE_STATES } from 'ee/workspaces/common/constants';

describe('OpenWorkspaceButton', () => {
  let wrapper;

  const createWrapper = ({ workspaceDisplayState, workspaceUrl }) => {
    wrapper = shallowMount(OpenWorkspaceButton, {
      propsData: {
        workspaceDisplayState,
        workspaceUrl,
      },
    });
  };

  describe(`when workspace display state is ${WORKSPACE_STATES.running}`, () => {
    describe('when workspace has URL', () => {
      it('displays "Open Workspace" button', () => {
        createWrapper({
          workspaceDisplayState: WORKSPACE_STATES.running,
          workspaceUrl: 'http://example.com/',
        });

        expect(wrapper.findComponent(GlButton).text()).toContain('Open workspace');
      });
    });

    describe('when workspace does not have URL', () => {
      it('does not display "Open Workspace" button', () => {
        createWrapper({
          workspaceDisplayState: WORKSPACE_STATES.running,
          workspaceUrl: '',
        });

        expect(wrapper.findComponent(GlButton).exists()).toBe(false);
      });
    });
  });

  describe.each([WORKSPACE_STATES.creationRequested, WORKSPACE_STATES.starting])(
    `when workspace display state is %s`,
    (workspaceDisplayState) => {
      it('displays starting workspace loading button', () => {
        createWrapper({
          workspaceDisplayState,
          workspaceUrl: '',
        });

        expect(wrapper.findComponent(GlButton).text()).toContain('Starting workspace');
      });
    },
  );

  describe.each([
    WORKSPACE_STATES.stopping,
    WORKSPACE_STATES.stopped,
    WORKSPACE_STATES.failed,
    WORKSPACE_STATES.error,
    WORKSPACE_STATES.unknown,
    WORKSPACE_STATES.terminated,
    WORKSPACE_STATES.terminating,
  ])(`when workspace display state is %s`, (workspaceDisplayState) => {
    it('displays no button', () => {
      createWrapper({
        workspaceDisplayState,
        workspaceUrl: 'http://example.com/',
      });

      expect(wrapper.findComponent(GlButton).exists()).toBe(false);
    });
  });
});
