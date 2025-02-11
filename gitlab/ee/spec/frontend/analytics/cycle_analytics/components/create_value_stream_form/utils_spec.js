import {
  ERRORS,
  NAME_MAX_LENGTH,
  editableFormFieldKeys,
} from 'ee/analytics/cycle_analytics/components/create_value_stream_form/constants';
import {
  validateStage,
  validateValueStreamName,
  hasDirtyStage,
  formatStageDataForSubmission,
  generateInitialStageData,
  cleanStageName,
} from 'ee/analytics/cycle_analytics/components/create_value_stream_form/utils';
import { labelStartEvent, labelEndEvent } from 'ee_jest/analytics/cycle_analytics/mock_data';

describe('cleanStageName', () => {
  it.each`
    value       | result
    ${'Issue'}  | ${'issue'}
    ${' Code '} | ${'code'}
    ${'PlAn '}  | ${'plan'}
  `('returns `$result` when given `$value`', ({ result, value }) => {
    expect(cleanStageName(value)).toBe(result);
  });
});

describe('validateStage', () => {
  const defaultFields = {
    name: '',
    startEventIdentifier: '',
    startEventLabelId: '',
    endEventIdentifier: '',
    endEventLabelId: '',
    custom: true,
  };

  const expectFieldError = ({ error, field, result }) =>
    expect(result).toMatchObject({ [field]: [error] });

  describe('name field', () => {
    const currentStageNames = ['issue', 'Plan', 'code', 'Test'];

    it.each`
      value                              | error                       | msg
      ${'a'.repeat(NAME_MAX_LENGTH + 1)} | ${ERRORS.MAX_LENGTH}        | ${'is too long'}
      ${'issue'}                         | ${ERRORS.STAGE_NAME_EXISTS} | ${'is a lowercase default name'}
      ${'Issue'}                         | ${ERRORS.STAGE_NAME_EXISTS} | ${'is a capitalized default name'}
      ${' Code '}                        | ${ERRORS.STAGE_NAME_EXISTS} | ${'has whitespace'}
    `('returns "$error" if name field $msg', ({ value, error }) => {
      const result = validateStage({
        currentStage: { ...defaultFields, name: value },
        allStageNames: currentStageNames.concat(cleanStageName(value)),
      });
      expectFieldError({ result, error, field: 'name' });
    });
  });

  describe('event fields', () => {
    it(`returns correct error message when no start event set`, () => {
      const result = validateStage({ currentStage: defaultFields });

      expectFieldError({
        result,
        error: 'Start event is required',
        field: 'startEventIdentifier',
      });
    });

    it(`returns correct error message with a start event but no end event set`, () => {
      const result = validateStage({
        currentStage: { ...defaultFields, startEventIdentifier: 'start-event' },
      });
      expectFieldError({ result, error: 'End event is required', field: 'endEventIdentifier' });
    });

    it('returns the correct error message when start event label is required', () => {
      const result = validateStage({
        currentStage: {
          name: 'cool stage',
          startEventIdentifier: labelStartEvent.identifier,
          endEventIdentifier: 'end-event',
        },
        labelEvents: [labelStartEvent.identifier],
      });

      expectFieldError({ result, error: 'Label is required', field: 'startEventLabelId' });
    });

    it('returns the correct error message when end event label is required', () => {
      const result = validateStage({
        currentStage: {
          ...defaultFields,
          startEventIdentifier: labelStartEvent.identifier,
          endEventIdentifier: labelEndEvent.identifier,
        },
        labelEvents: [labelEndEvent.identifier],
      });

      expectFieldError({ result, error: 'Label is required', field: 'endEventLabelId' });
    });
  });
});

describe('validateValueStreamName', () => {
  it('with valid data returns an empty array', () => {
    expect(validateValueStreamName({ name: 'Cool stream name' })).toEqual([]);
  });

  it.each`
    name                               | error                                  | msg
    ${'a'.repeat(NAME_MAX_LENGTH + 1)} | ${ERRORS.MAX_LENGTH}                   | ${'too long'}
    ${''}                              | ${ERRORS.VALUE_STREAM_NAME_REQUIRED}   | ${'blank'}
    ${'aa'}                            | ${ERRORS.VALUE_STREAM_NAME_MIN_LENGTH} | ${'too short'}
  `('returns "$error" if name is $msg', ({ name, error }) => {
    const result = validateValueStreamName({ name });
    expect(result).toEqual([error]);
  });
});

describe('hasDirtyStage', () => {
  const fakeStages = [
    { id: 10, name: 'Fake new stage', startEventIdentifier: 'issue_created' },
    { id: null, name: 'Fake new stage 2' },
  ];

  it('will return false if all required fields are equal for all stages', () => {
    expect(hasDirtyStage(fakeStages, fakeStages)).toBe(false);
  });

  it('will return true if any stage field value is different', () => {
    expect(hasDirtyStage(fakeStages, [{}, ...fakeStages])).toBe(true);
    expect(hasDirtyStage(fakeStages, [fakeStages, {}])).toBe(true);
    expect(
      hasDirtyStage(fakeStages, [
        fakeStages[0],
        { ...fakeStages[1], endEventIdentifier: 'issue_closed' },
      ]),
    ).toBe(true);
  });

  it('will ignore fields that are not required for the form', () => {
    expect(
      hasDirtyStage(fakeStages, [fakeStages[0], { ...fakeStages[1], fakeField: 'issue_closed' }]),
    ).toBe(false);
  });
});

describe('formatStageDataForSubmission', () => {
  let res = {};
  const fakeStage = {
    id: null,
    name: 'Fake new stage',
    startEventIdentifier: 'issue_created',
    endEventIdentifier: 'issue_closed',
    startEventLabelId: 'label A',
    endEventLabelId: 'label B',
  };

  describe('default stages', () => {
    beforeEach(() => {
      [res] = formatStageDataForSubmission([fakeStage]);
    });

    it('will not include the `id`', () => {
      expect(Object.keys(res).includes('id')).toBe(false);
    });

    it('will only include editable fields', () => {
      Object.keys(res).forEach((field) => {
        expect(editableFormFieldKeys.includes(field)).toBe(true);
      });
    });

    it('will convert all properties to snake case', () => {
      expect(Object.keys(res)).toEqual(['custom', 'name']);
    });

    it('will set custom to `false`', () => {
      expect(res.custom).toBe(false);
    });
  });

  describe('with a custom stage', () => {
    beforeEach(() => {
      [res] = formatStageDataForSubmission([{ ...fakeStage, custom: true }]);
    });

    it('will convert all properties to snake case', () => {
      expect(Object.keys(res)).toEqual([
        'start_event_identifier',
        'end_event_identifier',
        'start_event_label_id',
        'end_event_label_id',
        'custom',
        'name',
      ]);
    });

    it('will include the event fields', () => {
      [
        'start_event_identifier',
        'start_event_label_id',
        'end_event_identifier',
        'end_event_label_id',
      ].forEach((field) => {
        expect(Object.keys(res).includes(field)).toBe(true);
      });
    });
  });

  describe('isEditing = true', () => {
    it('will include the `id` if it has a value', () => {
      [res] = formatStageDataForSubmission([{ ...fakeStage, id: 10, custom: true }], true);
      expect(Object.keys(res).includes('id')).toBe(true);
    });

    it('will set custom to `true`', () => {
      [res] = formatStageDataForSubmission([{ ...fakeStage, custom: true }], true);
      expect(res.custom).toBe(true);
    });
  });
});

describe('generateInitialStageData', () => {
  const defaultConfig = {
    name: 'issue',
    custom: false,
    startEventIdentifier: 'issue_created',
    endEventIdentifier: 'issue_stage_end',
  };

  const initialDefaultStage = {
    id: 0,
    name: 'issue',
    startEventIdentifier: null,
    endEventIdentifier: null,
    custom: false,
  };

  const initialCustomStage = {
    id: 2,
    name: 'custom issue',
    startEventIdentifier: 'merge_request_created',
    endEventIdentifier: 'merge_request_closed',
    startEventLabel: {
      id: 'label_added',
    },
    endEventLabel: {
      id: 'label_removed',
    },
    custom: true,
  };

  describe('valid default stages', () => {
    it.each`
      key                       | value
      ${'startEventIdentifier'} | ${defaultConfig.startEventIdentifier}
      ${'endEventIdentifier'}   | ${defaultConfig.endEventIdentifier}
      ${'isDefault'}            | ${true}
    `('sets the $key field', ({ key, value }) => {
      const [res] = generateInitialStageData([defaultConfig], [initialDefaultStage]);

      expect(res[key]).toEqual(value);
    });
  });

  it('will return an empty object for an invalid default stages', () => {
    const [res] = generateInitialStageData(
      [defaultConfig],
      [{ ...initialDefaultStage, name: 'issue-fake' }],
    );

    expect(res).toEqual({});
  });

  it('will set missing default stages to `hidden`', () => {
    const hiddenStage = {
      id: 'fake-hidden',
      name: 'fake-hidden',
      custom: false,
      startEventIdentifier: 'merge_request_created',
      endEventIdentifier: 'merge_request_closed',
    };
    const res = generateInitialStageData([initialCustomStage, hiddenStage], [initialCustomStage]);

    expect(res[1]).toEqual({ ...hiddenStage, hidden: true, isDefault: true });
  });

  describe('custom stages', () => {
    it.each`
      key                       | value
      ${'startEventIdentifier'} | ${initialCustomStage.startEventIdentifier}
      ${'endEventIdentifier'}   | ${initialCustomStage.endEventIdentifier}
      ${'startEventLabelId'}    | ${initialCustomStage.startEventLabel.id}
      ${'endEventLabelId'}      | ${initialCustomStage.endEventLabel.id}
      ${'isDefault'}            | ${false}
    `('sets the $key field', ({ key, value }) => {
      const [res] = generateInitialStageData([defaultConfig], [initialCustomStage]);

      expect(res[key]).toEqual(value);
    });
  });
});
