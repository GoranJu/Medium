import { GlEmptyState } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { DEFAULT_ASSIGNED_POLICY_PROJECT } from 'ee/security_orchestration/constants';
import EditorComponent from 'ee/security_orchestration/components/policy_editor/pipeline_execution/editor_component.vue';
import ActionSection from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/action_section.vue';
import RuleSection from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/rule_section.vue';
import EditorLayout from 'ee/security_orchestration/components/policy_editor/editor_layout.vue';
import SkipCiSelector from 'ee/security_orchestration/components/policy_editor/skip_ci_selector.vue';
import {
  DEFAULT_PIPELINE_EXECUTION_POLICY,
  DEFAULT_PIPELINE_EXECUTION_POLICY_NEW_FORMAT,
  SUFFIX_NEVER,
  SUFFIX_ON_CONFLICT,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';
import { doesFileExist } from 'ee/security_orchestration/components/policy_editor/utils';
import { SECURITY_POLICY_ACTIONS } from 'ee/security_orchestration/components/policy_editor/constants';

import { ASSIGNED_POLICY_PROJECT } from 'ee_jest/security_orchestration/mocks/mock_data';
import {
  mockPipelineExecutionManifest,
  mockWithoutRefPipelineExecutionManifest,
  mockWithoutRefPipelineExecutionObject,
  mockInvalidPipelineExecutionObject,
  customYamlUrlParams,
} from 'ee_jest/security_orchestration/mocks/mock_pipeline_execution_policy_data';
import { goToYamlMode } from '../policy_editor_helper';

jest.mock('ee/security_orchestration/components/policy_editor/utils', () => ({
  ...jest.requireActual('ee/security_orchestration/components/policy_editor/utils'),
  doesFileExist: jest.fn().mockResolvedValue({
    data: {
      project: {
        repository: {
          blobs: {
            nodes: [{ fileName: 'file ' }],
          },
        },
      },
    },
  }),
}));

describe('EditorComponent', () => {
  let wrapper;
  const policyEditorEmptyStateSvgPath = 'path/to/svg';
  const scanPolicyDocumentationPath = 'path/to/docs';
  const defaultProjectPath = 'path/to/project';

  const factory = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(EditorComponent, {
      propsData: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        isCreating: false,
        isDeleting: false,
        isEditing: false,
        ...propsData,
      },
      provide: {
        disableScanPolicyUpdate: false,
        namespacePath: defaultProjectPath,
        policyEditorEmptyStateSvgPath,
        scanPolicyDocumentationPath,
        ...provide,
      },
    });
  };

  const factoryWithExistingPolicy = ({ policy = {}, provide = {} } = {}) => {
    return factory({
      propsData: {
        assignedPolicyProject: ASSIGNED_POLICY_PROJECT,
        existingPolicy: { ...mockWithoutRefPipelineExecutionObject, ...policy },
        isEditing: true,
      },
      provide,
    });
  };

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findPolicyEditorLayout = () => wrapper.findComponent(EditorLayout);
  const findActionSection = () => wrapper.findComponent(ActionSection);
  const findRuleSection = () => wrapper.findComponent(RuleSection);
  const findDisabledAction = () => wrapper.findByTestId('disabled-action');
  const findSkipCiSelector = () => wrapper.findComponent(SkipCiSelector);

  describe('when url params are passed', () => {
    beforeEach(() => {
      Object.defineProperty(window, 'location', {
        writable: true,
        value: { search: '' },
      });

      window.location.search = new URLSearchParams(Object.entries(customYamlUrlParams)).toString();
      factory();
    });

    it('configures initial policy from passed url params', () => {
      expect(findPolicyEditorLayout().props('policy')).toMatchObject({
        type: customYamlUrlParams.type,
        content: {
          include: [{ file: 'foo', project: 'bar' }],
        },
        pipeline_config_strategy: 'override_project_ci',
        metadata: {
          compliance_pipeline_migration: true,
        },
      });
    });

    it('saves a new policy with correct title and description', async () => {
      findPolicyEditorLayout().vm.$emit('save-policy');
      await waitForPromises();

      expect(wrapper.emitted('save')[0]).toHaveLength(1);
      expect(wrapper.emitted('save')[0][0]).toMatchObject({
        extraMergeRequestInput: expect.objectContaining({
          title: 'Compliance pipeline migration to pipeline execution policy',
          description: expect.stringContaining('This merge request migrates compliance pipeline'),
        }),
      });
    });

    it('uses absolute links in description', async () => {
      findPolicyEditorLayout().vm.$emit('save-policy');
      await waitForPromises();

      expect(wrapper.emitted('save')[0][0]).toMatchObject({
        extraMergeRequestInput: expect.objectContaining({
          description: expect.stringContaining(
            `[Foo](http://test.host/groups/path/to/project/-/security/compliance_dashboard/frameworks/1)`,
          ),
        }),
      });
    });

    afterEach(() => {
      window.location.search = '';
    });
  });

  describe('rule mode', () => {
    const error =
      'The current YAML syntax is invalid so you cannot edit the actions in rule mode. To resolve the issue, switch to YAML mode and fix the syntax.';

    it('renders the editor', () => {
      factory();
      expect(findPolicyEditorLayout().exists()).toBe(true);
      expect(findActionSection().exists()).toBe(true);
      expect(findRuleSection().exists()).toBe(true);
      expect(findEmptyState().exists()).toBe(false);
      expect(findDisabledAction().props()).toEqual({ disabled: false, error });
    });

    it('renders the default policy editor layout', () => {
      factory();
      const editorLayout = findPolicyEditorLayout();
      expect(editorLayout.exists()).toBe(true);
      expect(editorLayout.props()).toEqual(
        expect.objectContaining({ yamlEditorValue: DEFAULT_PIPELINE_EXECUTION_POLICY }),
      );
    });

    it('updates the general policy properties', async () => {
      const name = 'New name';
      factory();
      expect(findPolicyEditorLayout().props('policy').name).toBe('');
      expect(findPolicyEditorLayout().props('yamlEditorValue')).toContain("name: ''");
      await findPolicyEditorLayout().vm.$emit('update-property', 'name', name);
      expect(findPolicyEditorLayout().props('policy').name).toBe(name);
      expect(findPolicyEditorLayout().props('yamlEditorValue')).toContain(`name: ${name}`);
    });

    it('disables the action if there is an action validation error', () => {
      factoryWithExistingPolicy({ policy: mockInvalidPipelineExecutionObject });
      expect(findActionSection().exists()).toBe(true);
      expect(findDisabledAction().props()).toEqual({ disabled: true, error });
    });
  });

  describe('yaml mode', () => {
    it('updates the policy', async () => {
      factory();
      await findPolicyEditorLayout().vm.$emit(
        'update-yaml',
        mockWithoutRefPipelineExecutionManifest,
      );
      expect(findPolicyEditorLayout().props('policy')).toEqual(
        mockWithoutRefPipelineExecutionObject,
      );
      expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(
        mockWithoutRefPipelineExecutionManifest,
      );
    });
  });

  describe('empty page', () => {
    it('renders', () => {
      factory({ provide: { disableScanPolicyUpdate: true } });
      expect(findPolicyEditorLayout().exists()).toBe(false);
      expect(findActionSection().exists()).toBe(false);
      expect(findRuleSection().exists()).toBe(false);

      const emptyState = findEmptyState();
      expect(emptyState.exists()).toBe(true);
      expect(emptyState.props('primaryButtonLink')).toMatch(scanPolicyDocumentationPath);
      expect(emptyState.props('primaryButtonLink')).toMatch('pipeline-execution-policy-editor');
      expect(emptyState.props('svgPath')).toBe(policyEditorEmptyStateSvgPath);
    });
  });

  describe('modifying a policy', () => {
    it.each`
      status                           | action                            | event              | factoryFn                    | yamlEditorValue
      ${'creating a new policy'}       | ${undefined}                      | ${'save-policy'}   | ${factory}                   | ${DEFAULT_PIPELINE_EXECUTION_POLICY}
      ${'updating an existing policy'} | ${undefined}                      | ${'save-policy'}   | ${factoryWithExistingPolicy} | ${mockWithoutRefPipelineExecutionManifest}
      ${'deleting an existing policy'} | ${SECURITY_POLICY_ACTIONS.REMOVE} | ${'remove-policy'} | ${factoryWithExistingPolicy} | ${mockWithoutRefPipelineExecutionManifest}
    `('emits "save" when $status', async ({ action, event, factoryFn, yamlEditorValue }) => {
      factoryFn();
      findPolicyEditorLayout().vm.$emit(event);
      await waitForPromises();
      expect(wrapper.emitted('save')).toEqual([
        [{ action, extraMergeRequestInput: null, policy: yamlEditorValue }],
      ]);
    });
  });

  describe('action validation error', () => {
    describe('no validation', () => {
      it('does not validate on new linked file section', () => {
        factory();
        expect(doesFileExist).toHaveBeenCalledTimes(0);
      });
    });

    describe('new policy', () => {
      beforeEach(async () => {
        factory();
        await findPolicyEditorLayout().vm.$emit('update-property', 'name', 'New name');
      });

      it.each`
        payload                                                                       | expectedResult
        ${{ include: [{ project: 'project-path' }] }}                                 | ${{ filePath: undefined, fullPath: 'project-path', ref: null }}
        ${{ include: [{ project: 'project-path', ref: 'main', file: 'file-name' }] }} | ${{ filePath: 'file-name', fullPath: 'project-path', ref: 'main' }}
      `('makes a call to validate the selection', async ({ payload, expectedResult }) => {
        expect(doesFileExist).toHaveBeenCalledTimes(0);

        await findActionSection().vm.$emit('set-ref', 'main');
        await findActionSection().vm.$emit('changed', 'content', payload);

        expect(doesFileExist).toHaveBeenCalledWith(expectedResult);
      });

      it('calls validation when switched to yaml mode', async () => {
        await goToYamlMode(findPolicyEditorLayout);

        expect(doesFileExist).toHaveBeenCalledTimes(0);

        await findPolicyEditorLayout().vm.$emit('update-yaml', mockPipelineExecutionManifest);

        expect(doesFileExist).toHaveBeenCalledWith({
          filePath: 'pipeline_execution_jobs.yml',
          fullPath: 'gitlab-policies/js6',
          ref: 'main',
        });
      });
    });

    describe('existing policy', () => {
      beforeEach(() => {
        mockWithoutRefPipelineExecutionObject.content.include[0].ref = 'main';
        factory({
          propsData: {
            existingPolicy: { ...mockWithoutRefPipelineExecutionObject },
          },
        });
      });
      it('validates on existing policy initial state', () => {
        expect(doesFileExist).toHaveBeenCalledWith({
          filePath: '.pipeline-execution.yml',
          fullPath: 'GitLab.org/GitLab',
          ref: 'main',
        });
      });

      it.each`
        payload                                                                       | expectedResult
        ${{ include: [{ project: 'project-path' }] }}                                 | ${{ filePath: undefined, fullPath: 'project-path', ref: null }}
        ${{ include: [{ project: 'project-path', ref: 'main', file: 'file-name' }] }} | ${{ filePath: 'file-name', fullPath: 'project-path', ref: 'main' }}
      `('makes a call to validate the selection', async ({ payload, expectedResult }) => {
        expect(doesFileExist).toHaveBeenCalledTimes(1);

        await findActionSection().vm.$emit('set-ref', 'main');
        await findActionSection().vm.$emit('changed', 'content', payload);

        expect(doesFileExist).toHaveBeenCalledWith(expectedResult);
      });
    });
  });

  describe('suffix editor', () => {
    beforeEach(() => {
      factory();
    });

    it('has suffix in action section', () => {
      expect(findActionSection().props('suffix')).toBe(SUFFIX_ON_CONFLICT);
    });

    it('selects suffix strategy', () => {
      findActionSection().vm.$emit('changed', 'suffix', SUFFIX_NEVER);
      expect(findPolicyEditorLayout().props('policy').suffix).toEqual(SUFFIX_NEVER);
    });
  });

  describe('skip ci configuration', () => {
    it('renders skip ci configuration', () => {
      factory({
        provide: {
          glFeatures: {
            securityPoliciesSkipCi: true,
          },
        },
      });

      expect(findSkipCiSelector().exists()).toBe(true);
      expect(findSkipCiSelector().props('skipCiConfiguration')).toEqual({});
    });
  });

  describe('new yaml format with type as a wrapper', () => {
    beforeEach(() => {
      window.gon.features = {
        securityPoliciesNewYamlFormat: true,
      };

      factory({
        provide: {
          glFeatures: {
            securityPoliciesNewYamlFormat: true,
          },
        },
      });
    });

    it('renders default yaml in new format', () => {
      expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(
        DEFAULT_PIPELINE_EXECUTION_POLICY_NEW_FORMAT,
      );
    });

    it('converts new policy format to old policy format when saved', async () => {
      findPolicyEditorLayout().vm.$emit('save-policy');
      await waitForPromises();

      expect(wrapper.emitted('save')).toEqual([
        [
          {
            action: undefined,
            extraMergeRequestInput: null,
            policy: `name: ''
description: ''
enabled: true
pipeline_config_strategy: inject_ci
content:
  include:
    - project: ''
type: pipeline_execution_policy
`,
          },
        ],
      ]);
    });
  });
});
